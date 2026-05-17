import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

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
    return Obx(() {
      final c = AppTheme.current;
      return GetCupertinoApp(
        title: 'SignBridge',
        debugShowCheckedModeBanner: false,
        theme: CupertinoThemeData(
          brightness: c.brightness,
          primaryColor: c.accent,
          scaffoldBackgroundColor: c.background,
          barBackgroundColor: c.surface,
          textTheme: CupertinoTextThemeData(
            primaryColor: c.textPrimary,
            textStyle: TextStyle(color: c.textPrimary, fontSize: 16),
          ),
        ),
        initialRoute: '/lobby',
        getPages: [
          GetPage(
            name: '/lobby',
            page: () {
              Get.put(LobbyController());
              return const LobbyPage();
            },
          ),
          GetPage(
            name: '/home',
            page: () {
              final args = Get.arguments as Map<String, dynamic>?;
              final role = args?['role'] as String? ?? 'signer';
              final roomId = args?['room_id'] as String? ?? '';
              final isCreator = args?['is_creator'] as bool? ?? false;
              Get.put(
                HomePageController(
                  autoBootstrap: false,
                  role: role,
                  roomId: roomId,
                  isCreator: isCreator,
                ),
              );
              return HomePage(role: role, roomId: roomId);
            },
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
    });
  }
}
