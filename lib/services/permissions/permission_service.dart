import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

enum PermissionState { unknown, granted, denied, permanentlyDenied }

class PermissionService extends GetxService {
  final Rx<PermissionState> cameraState = PermissionState.unknown.obs;
  final Rx<PermissionState> microphoneState = PermissionState.unknown.obs;

  Future<bool> ensureCameraAndMic() async {
    if (kIsWeb) {
      cameraState.value = PermissionState.granted;
      microphoneState.value = PermissionState.granted;
      return true;
    }

    final statuses = await [Permission.camera, Permission.microphone].request();
    cameraState.value = _map(statuses[Permission.camera]);
    microphoneState.value = _map(statuses[Permission.microphone]);

    return cameraState.value == PermissionState.granted &&
        microphoneState.value == PermissionState.granted;
  }

  PermissionState _map(PermissionStatus? status) {
    if (status == null) return PermissionState.unknown;
    if (status.isGranted) return PermissionState.granted;
    if (status.isPermanentlyDenied) return PermissionState.permanentlyDenied;
    return PermissionState.denied;
  }
}
