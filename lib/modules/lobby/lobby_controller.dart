import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import '../../services/connection/realtime_ws_service.dart';
import '../../services/settings/runtime_settings_service.dart';

class LobbyController extends GetxController {
  final roomCodeController = TextEditingController();
  final RxBool isCreating = false.obs;
  final RxBool isJoining = false.obs;
  final RxString errorMessage = ''.obs;

  late final RealtimeWsService _ws;
  late final RuntimeSettingsService _settings;

  @override
  void onInit() {
    super.onInit();
    _ws = Get.find<RealtimeWsService>();
    _settings = Get.find<RuntimeSettingsService>();
  }

  @override
  void onClose() {
    roomCodeController.dispose();
    super.onClose();
  }

  Future<void> createRoom(String role) async {
    isCreating.value = true;
    errorMessage.value = '';
    try {
      await _ws.connect();
      final roomId = await _ws.createRoom(role);
      if (roomId != null) {
        _settings.setRoomInfo(roomId, role);
        Get.offNamed('/home', arguments: {
          'room_id': roomId,
          'role': role,
        });
      } else {
        errorMessage.value = '创建房间失败，请检查网络连接';
      }
    } catch (e) {
      errorMessage.value = '创建房间失败: $e';
    } finally {
      isCreating.value = false;
    }
  }

  Future<void> joinRoom(String role) async {
    final code = roomCodeController.text.trim();
    if (code.length != 4) {
      errorMessage.value = '请输入4位房间号';
      return;
    }
    isJoining.value = true;
    errorMessage.value = '';
    try {
      await _ws.connect();
      final success = await _ws.joinRoom(code, role);
      if (success) {
        _settings.setRoomInfo(code, role);
        Get.offNamed('/home', arguments: {
          'room_id': code,
          'role': role,
        });
      } else {
        errorMessage.value = '加入房间失败，请检查房间号是否正确';
      }
    } catch (e) {
      errorMessage.value = '加入房间失败: $e';
    } finally {
      isJoining.value = false;
    }
  }
}
