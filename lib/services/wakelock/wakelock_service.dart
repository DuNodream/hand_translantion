import 'package:get/get.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class WakeLockService extends GetxService {
  final RxBool enabled = true.obs;

  void toggle() {
    enabled.value = !enabled.value;
    if (enabled.value) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  void enable() {
    enabled.value = true;
    WakelockPlus.enable();
  }

  void disable() {
    enabled.value = false;
    WakelockPlus.disable();
  }
}
