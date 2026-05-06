import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import '../modules/home/bindings/home_binding.dart';
import '../modules/home/controllers/home_page_controller.dart';
import '../modules/home/views/home_page.dart';
import '../modules/lobby/lobby_controller.dart';
import '../modules/lobby/lobby_page.dart';
import '../modules/settings/controllers/settings_controller.dart';
import '../modules/settings/views/settings_page.dart';
import '../shared/themes/app_theme.dart';

class SignBridgeApp extends StatelessWidget {
  const SignBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetCupertinoApp(
      title: 'SignBridge',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.cupertinoTheme,
      initialRoute: '/lobby',
      getPages: [
        GetPage(
          name: '/lobby',
          page: () {
            Get.put(LobbyController(), permanent: true);
            return const LobbyPage();
          },
        ),
        GetPage(
          name: '/home',
          page: () {
            final args = Get.arguments as Map<String, dynamic>?;
            final role = args?['role'] as String? ?? 'signer';
            final roomId = args?['room_id'] as String? ?? '';
            Get.put(
              HomePageController(autoBootstrap: false, role: role, roomId: roomId),
              permanent: true,
            );
            return HomePage(role: role, roomId: roomId);
          },
          binding: HomeBinding(),
        ),
        GetPage(
          name: '/settings',
          page: () {
            Get.put(SettingsController());
            return const SettingsPage();
          },
        ),
      ],
    );
  }
}
