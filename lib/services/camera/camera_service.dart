import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;

import '../connection/realtime_ws_service.dart';
import '../debug/debug_log_service.dart';
import '../permissions/permission_service.dart';

enum CameraState {
  idle,
  requestingPermission,
  permissionDenied,
  unavailable,
  initializing,
  ready,
  streaming,
  error,
}

/// PR-4: 人像检测状态机。
/// noPerson  -> [连续命中 N 次] -> detected
/// detected -> [连续 miss M 次] -> coolingDown (仍显示 personInFrame=true)
/// coolingDown -> [2s 后仍未恢复] -> noPerson
enum PersonDetectState { noPerson, detected, coolingDown }

class CameraService extends GetxService {
  CameraService({
    required PermissionService permissionService,
    required RealtimeWsService wsService,
    DebugLogService? debugLogService,
  }) : _permissionService = permissionService,
       _wsService = wsService,
       _debugLogService = debugLogService;

  final PermissionService _permissionService;
  final RealtimeWsService _wsService;
  final DebugLogService? _debugLogService;

  final Rx<CameraState> state = CameraState.idle.obs;
  final RxnString errorText = RxnString();
  // personInFrame 表示“人像可见”的最终状态（经过 debounce/cooldown 后）
  final RxBool personInFrame = false.obs;

  CameraController? controller;
  Timer? _webCaptureTimer;
  bool _processing = false;
  DateTime _lastSentAt = DateTime.fromMillisecondsSinceEpoch(0);
  int _analysisFrameSkip = 0;

  // === PR-4: 人像检测状态机 ===
  static const int _kHitThreshold = 3;   // 连续命中次数 -> detected
  static const int _kMissThreshold = 3;  // 连续未命中 -> coolingDown
  static const Duration _kCooldownDuration = Duration(seconds: 2);
  static const Duration _kMinVisibleDuration = Duration(milliseconds: 800);
  PersonDetectState _personState = PersonDetectState.noPerson;
  int _personHitCount = 0;
  int _personMissCount = 0;
  DateTime _personEnteredAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _personLostAt = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _cooldownTimer;

  Future<void> initialize() async {
    if (state.value == CameraState.initializing ||
        state.value == CameraState.ready ||
        state.value == CameraState.streaming) {
      _log('initialize skipped because state=${state.value.name}');
      return;
    }

    try {
      state.value = CameraState.requestingPermission;
      _log('request camera permissions');
      final granted = await _permissionService.ensureCameraAndMic();
      if (!granted) {
        state.value = CameraState.permissionDenied;
        _log('permissions denied');
        return;
      }

      state.value = CameraState.initializing;
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        state.value = CameraState.unavailable;
        _log('no cameras found');
        return;
      }

      final selected = cameras
          .where((item) => item.lensDirection == CameraLensDirection.front)
          .cast<CameraDescription?>()
          .firstWhere((item) => item != null, orElse: () => cameras.first);

      final imageFormat = kIsWeb
          ? ImageFormatGroup.jpeg
          : defaultTargetPlatform == TargetPlatform.iOS
              ? ImageFormatGroup.bgra8888
              : ImageFormatGroup.yuv420;

      controller = CameraController(
        selected!,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: imageFormat,
      );

      await controller!.initialize();
      state.value = CameraState.ready;
      _log('camera initialized');
    } catch (error) {
      errorText.value = error.toString();
      state.value = CameraState.error;
      _log('camera init error: $error');
    }
  }

  Future<void> startCapture() async {
    if (controller == null || state.value == CameraState.permissionDenied) {
      _log('startCapture skipped');
      return;
    }

    if (kIsWeb) {
      _webCaptureTimer?.cancel();
      _webCaptureTimer = Timer.periodic(
        const Duration(milliseconds: 350),
        (_) => captureWebFrame(),
      );
      state.value = CameraState.streaming;
      _log('web capture timer started');
      return;
    }

    if (controller!.value.isStreamingImages) {
      _log('image stream already running');
      return;
    }

    await controller!.startImageStream((image) async {
      // 人像检测独立于 WebSocket 发送逻辑，每帧都检测
      _analyzeForPerson(image);

      if (_processing || !_shouldSendFrame()) return;
      _processing = true;
      _lastSentAt = DateTime.now();
      try {
        final jpegBytes = await compute(
          _encodeCameraImage,
          CameraImagePayload.from(image),
        );
        if (jpegBytes != null) {
          _wsService.sendFrame(jpegBytes);
        }
      } finally {
        _processing = false;
      }
    });
    state.value = CameraState.streaming;
    _log('native image stream started');
  }

  Future<void> captureWebFrame() async {
    if (!kIsWeb || controller == null || !_shouldSendFrame()) return;
    if (_processing || !controller!.value.isInitialized) return;
    _processing = true;
    _lastSentAt = DateTime.now();
    try {
      final image = await controller!.takePicture();
      final bytes = await image.readAsBytes();
      _wsService.sendFrame(bytes);
    } catch (error) {
      errorText.value = error.toString();
      _log('web frame capture error: $error');
    } finally {
      _processing = false;
    }
  }

  void _analyzeForPerson(CameraImage image) {
    _analysisFrameSkip++;
    if (_analysisFrameSkip % 5 != 0) return; // every 5th frame

    final w = image.width;
    final h = image.height;
    final cx = w ~/ 2, cy = h ~/ 2;
    // 中心 40%×50% 区域（覆盖头部双肩和上半身）
    final rw = (w * 0.40).round().clamp(8, 640);
    final rh = (h * 0.50).round().clamp(8, 800);
    final x1 = (cx - rw ~/ 2).clamp(0, w - rw - 1);
    final y1 = (cy - rh ~/ 2).clamp(0, h - rh - 1);

    bool rawHit = false;
    try {
      final (centerMean, centerVar) = _sampleVariance(image, x1, y1, rw, rh);
      // 采样左右边缘亮度，与中心对比（人在时中心亮度明显异于背景）
      final edgeW = (w * 0.10).round().clamp(8, 80);
      final (leftMean, _) = _sampleVariance(image, 0, y1, edgeW, rh);
      final (rightMean, _) = _sampleVariance(image, w - edgeW - 1, y1, edgeW, rh);
      final edgeMean = (leftMean + rightMean) / 2.0;
      final centerDiff = (centerMean - edgeMean).abs();
      // 中心有纹理 + 亮度与边缘差异显著 → 人在画面中
      rawHit = centerVar > 150.0 && centerDiff > 25.0;
    } catch (e) {
      _log('person analysis error: $e');
      return;
    }
    _updatePersonState(rawHit);
  }

  /// PR-4: 状态机核心。只在状态跳转时才更新 personInFrame，避免 UI 闪烁。
  void _updatePersonState(bool rawHit) {
    final now = DateTime.now();

    if (rawHit) {
      _personHitCount++;
      _personMissCount = 0;
    } else {
      _personMissCount++;
      _personHitCount = 0;
    }

    final prev = _personState;
    switch (_personState) {
      case PersonDetectState.noPerson:
        if (_personHitCount >= _kHitThreshold) {
          _personState = PersonDetectState.detected;
          _personEnteredAt = now;
          _cooldownTimer?.cancel();
          _cooldownTimer = null;
          personInFrame.value = true;
        }
        break;
      case PersonDetectState.detected:
        // 最小可见时长未到 -> 不允许退出
        if (now.difference(_personEnteredAt) < _kMinVisibleDuration) {
          break;
        }
        if (_personMissCount >= _kMissThreshold) {
          _personState = PersonDetectState.coolingDown;
          _personLostAt = now;
          // personInFrame 暂不变，等 cooldown 超时后才隐藏
          _cooldownTimer?.cancel();
          _cooldownTimer = Timer(_kCooldownDuration, () {
            // cooldown 期间没有恬复 -> noPerson
            if (_personState == PersonDetectState.coolingDown) {
              _personState = PersonDetectState.noPerson;
              _personHitCount = 0;
              _personMissCount = 0;
              personInFrame.value = false;
              _log('[UI_STATE] COOLING_DOWN -> NO_PERSON');
            }
          });
        }
        break;
      case PersonDetectState.coolingDown:
        if (_personHitCount >= _kHitThreshold) {
          _personState = PersonDetectState.detected;
          _personEnteredAt = now;
          _cooldownTimer?.cancel();
          _cooldownTimer = null;
        }
        break;
    }

    if (prev != _personState) {
      _log('[UI_STATE] ${prev.name} -> ${_personState.name}  '
          'hit=$_personHitCount miss=$_personMissCount inFrame=${personInFrame.value}');
    }
  }

  /// 对指定区域采样亮度值，返回 (mean, variance)
  (double, double) _sampleVariance(CameraImage image, int x1, int y1, int rw, int rh, {int step = 3}) {
    final x2 = (x1 + rw).clamp(0, image.width - 1);
    final y2 = (y1 + rh).clamp(0, image.height - 1);

    double sum = 0, sumSq = 0;
    int count = 0;

    if (image.format.group == ImageFormatGroup.yuv420) {
      final yPlane = image.planes[0];
      final yBytes = yPlane.bytes;
      final rowStride = yPlane.bytesPerRow;

      for (int y = y1; y < y2; y += step) {
        final rowOffset = y * rowStride;
        for (int x = x1; x < x2; x += step) {
          final idx = rowOffset + x;
          if (idx >= yBytes.length) break;
          final val = yBytes[idx];
          sum += val;
          sumSq += val * val;
          count++;
        }
      }
    } else {
      // BGRA8888 — use blue channel as luminance approximation
      final plane = image.planes[0];
      final bytes = plane.bytes;
      final rowStride = plane.bytesPerRow;

      for (int y = y1; y < y2; y += step) {
        final rowOffset = y * rowStride;
        for (int x = x1; x < x2; x += step) {
          final offset = rowOffset + x * 4 + 2; // blue channel
          if (offset >= bytes.length) break;
          final val = bytes[offset];
          sum += val;
          sumSq += val * val;
          count++;
        }
      }
    }

    if (count == 0) return (0.0, 0.0);
    final mean = sum / count;
    final variance = (sumSq / count) - (mean * mean);
    return (mean, variance);
  }

  Future<void> restart() async {
    _log('restart camera');
    await stopCapture();
    await disposeCamera();
    await initialize();
    if (state.value == CameraState.ready) {
      await startCapture();
    }
  }

  Future<void> stopCapture() async {
    _webCaptureTimer?.cancel();
    _webCaptureTimer = null;
    _cooldownTimer?.cancel();
    _cooldownTimer = null;
    if (!kIsWeb && controller?.value.isStreamingImages == true) {
      await controller?.stopImageStream();
    }
    if (state.value == CameraState.streaming) {
      state.value = CameraState.ready;
    }
    _log('capture stopped');
  }

  Future<void> disposeCamera() async {
    await stopCapture();
    await controller?.dispose();
    controller = null;
    if (state.value != CameraState.permissionDenied &&
        state.value != CameraState.unavailable) {
      state.value = CameraState.idle;
    }
    _log('camera disposed');
  }

  bool _shouldSendFrame() {
    if (_wsService.state.value != WsState.connected) return false;
    final diff = DateTime.now().difference(_lastSentAt).inMilliseconds;
    return diff >= 120;
  }

  void _log(String message) {
    _debugLogService?.log('camera', message);
  }

  @override
  void onClose() {
    disposeCamera();
    super.onClose();
  }
}

class CameraImagePayload {
  CameraImagePayload({
    required this.width,
    required this.height,
    required this.format,
    required this.planes,
  });

  final int width;
  final int height;
  final CameraImageFormat format;
  final List<CameraPlanePayload> planes;

  factory CameraImagePayload.from(CameraImage image) {
    final format = image.format.group == ImageFormatGroup.bgra8888
        ? CameraImageFormat.bgra8888
        : CameraImageFormat.yuv420;
    return CameraImagePayload(
      width: image.width,
      height: image.height,
      format: format,
      planes: image.planes
          .map(
            (plane) => CameraPlanePayload(
              bytes: Uint8List.fromList(plane.bytes),
              bytesPerRow: plane.bytesPerRow,
              bytesPerPixel: plane.bytesPerPixel ?? 1,
            ),
          )
          .toList(),
    );
  }
}

class CameraPlanePayload {
  CameraPlanePayload({
    required this.bytes,
    required this.bytesPerRow,
    required this.bytesPerPixel,
  });

  final Uint8List bytes;
  final int bytesPerRow;
  final int bytesPerPixel;
}

enum CameraImageFormat { bgra8888, yuv420 }

Uint8List? _encodeCameraImage(CameraImagePayload payload) {
  try {
    img.Image image;
    if (payload.format == CameraImageFormat.bgra8888) {
      image = img.Image.fromBytes(
        width: payload.width,
        height: payload.height,
        bytes: payload.planes[0].bytes.buffer,
        order: img.ChannelOrder.bgra,
      );
      // BGRA 走原有 resize 路径
      final shortSide = image.width < image.height ? image.width : image.height;
      final scale = 320.0 / shortSide;
      image = img.copyResize(
        image,
        width: (image.width * scale).round(),
        height: (image.height * scale).round(),
      );
    } else {
      // PR-4: YUV 走加速路径，直接在转换时下采样
      image = _convertYuv420Downsampled(payload, targetShort: 320);
    }
    return img.encodeJpg(image, quality: 75);
  } catch (_) {
    return null;
  }
}

/// PR-4: YUV420 -> RGB 与下采样一步完成，跳过 90 万次 setPixelRgb 的冷热路径。
img.Image _convertYuv420Downsampled(CameraImagePayload payload,
    {int targetShort = 320}) {
  final width = payload.width;
  final height = payload.height;
  final short = width < height ? width : height;
  // stride 越大越快，但不能太大以充分保留手部细节
  var stride = (short / targetShort).floor();
  if (stride < 1) stride = 1;
  if (stride > 8) stride = 8;

  final outW = width ~/ stride;
  final outH = height ~/ stride;

  final yBytes = payload.planes[0].bytes;
  final uBytes = payload.planes[1].bytes;
  final vBytes = payload.planes[2].bytes;
  final yRowStride = payload.planes[0].bytesPerRow;
  final uvRowStride = payload.planes[1].bytesPerRow;
  final uvPixelStride = payload.planes[1].bytesPerPixel;

  final out = img.Image(width: outW, height: outH);
  final yLen = yBytes.length;
  final uLen = uBytes.length;
  final vLen = vBytes.length;

  for (var oy = 0; oy < outH; oy++) {
    final row = oy * stride;
    final rowBase = row * yRowStride;
    final uvRow = row >> 1;
    final uvRowBase = uvRow * uvRowStride;
    for (var ox = 0; ox < outW; ox++) {
      final col = ox * stride;
      final yIdx = rowBase + col;
      if (yIdx >= yLen) continue;
      final y = yBytes[yIdx];
      final uvIdx = uvRowBase + (col >> 1) * uvPixelStride;
      var u = 128, v = 128;
      if (uvIdx < uLen) u = uBytes[uvIdx];
      if (uvIdx < vLen) v = vBytes[uvIdx];
      final uShift = u - 128;
      final vShift = v - 128;
      final r = (y + 1.370705 * vShift).round().clamp(0, 255);
      final g = (y - 0.337633 * uShift - 0.698001 * vShift).round().clamp(0, 255);
      final b = (y + 1.732446 * uShift).round().clamp(0, 255);
      out.setPixelRgb(ox, oy, r, g, b);
    }
  }
  return out;
}

img.Image _convertYuv420(CameraImagePayload payload) {
  final width = payload.width;
  final height = payload.height;
  final yBytes = payload.planes[0].bytes;
  final uBytes = payload.planes[1].bytes;
  final vBytes = payload.planes[2].bytes;
  final yRowStride = payload.planes[0].bytesPerRow;
  final uvRowStride = payload.planes[1].bytesPerRow;
  final uvPixelStride = payload.planes[1].bytesPerPixel;

  final image = img.Image(width: width, height: height);
  for (var row = 0; row < height; row++) {
    for (var col = 0; col < width; col++) {
      final yIndex = row * yRowStride + col;
      if (yIndex >= yBytes.length) continue;

      final y = yBytes[yIndex];
      final uvRow = row ~/ 2;
      final uvCol = col ~/ 2;
      final uvIndex = uvRow * uvRowStride + uvCol * uvPixelStride;

      var u = 128;
      var v = 128;
      if (uvIndex < uBytes.length) u = uBytes[uvIndex];
      if (uvIndex < vBytes.length) v = vBytes[uvIndex];

      final r = (y + 1.370705 * (v - 128)).round().clamp(0, 255);
      final g = (y - 0.337633 * (u - 128) - 0.698001 * (v - 128))
          .round()
          .clamp(0, 255);
      final b = (y + 1.732446 * (u - 128)).round().clamp(0, 255);

      image.setPixelRgb(col, row, r, g, b);
    }
  }

  return image;
}
