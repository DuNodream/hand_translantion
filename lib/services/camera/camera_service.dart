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

  CameraController? controller;
  Timer? _webCaptureTimer;
  bool _processing = false;
  DateTime _lastSentAt = DateTime.fromMillisecondsSinceEpoch(0);

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
    final img.Image image = payload.format == CameraImageFormat.bgra8888
        ? img.Image.fromBytes(
            width: payload.width,
            height: payload.height,
            bytes: payload.planes[0].bytes.buffer,
            order: img.ChannelOrder.bgra,
          )
        : _convertYuv420(payload);

    final shortSide = image.width < image.height ? image.width : image.height;
    final scale = 320.0 / shortSide;
    final resized = img.copyResize(
      image,
      width: (image.width * scale).round(),
      height: (image.height * scale).round(),
    );
    return img.encodeJpg(resized, quality: 75);
  } catch (_) {
    return null;
  }
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
