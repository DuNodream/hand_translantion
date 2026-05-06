# Flutter Sign Language Frontend

面向医疗、政务与公共服务场景的手语识别前端。项目基于 Flutter，负责摄像头采集、WebSocket 实时通信、字幕展示、会话管理、语音输入与运行时配置，是一个可继续扩展为正式交付版本的前端骨架。

## 核心功能

- 前置摄像头实时预览与图像采样
- WebSocket 手语识别链路与自动重连
- 实时字幕区与会话区双通道展示
- 语音转文字、手动输入、快捷短语
- 权限引导、空状态、异常提示、运行中状态灯
- `dev / test / prod` 多环境配置与运行时服务地址切换

## 技术栈

- Flutter
- GetX
- camera
- web_socket_channel
- speech_to_text
- permission_handler
- image

## 架构设计

```text
lib/
├── app/                    # 入口、应用装配、全局绑定
├── config/                 # ENV / URL / Token 配置
├── data/models/            # 业务模型
├── modules/home/           # 首页模块、页面控制器与视图
├── services/               # websocket / camera / speech / session 等服务
└── shared/themes/          # 主题和视觉规范
```

### 关键职责

- `RealtimeWsService`：握手、心跳、重连、状态机、前后台恢复。
- `CameraService`：权限检查、摄像头初始化、图像流与 Web 兜底采样。
- `SessionService`：消息状态、字幕内容、识别结果落会话。
- `SpeechService`：语音输入与识别结果接入。
- `RuntimeSettingsService`：运行时服务地址与大字体模式。

## 本地运行

### 开发环境

```bash
flutter pub get
flutter run --dart-define=ENV=dev
```

### 指定识别服务地址

```bash
flutter run --dart-define=ENV=dev --dart-define=WS_URL=ws://10.0.2.2:8000/ws/recognize
```

### 生产示例

```bash
flutter run --dart-define=ENV=prod --dart-define=WS_URL=wss://example.com/ws/recognize --dart-define=AUTH_TOKEN=demo-token
```

## 多环境发布

- `ENV=dev`：本地联调
- `ENV=test`：测试或预演环境
- `ENV=prod`：演示或正式环境

默认配置位于 [lib/config/app_config.dart](/D:/a/flutter_sign_language_interpretation/lib/config/app_config.dart:1)。

## WebSocket 协议

### 客户端发送

```json
{"type":"hello","client":"flutter","version":"1.0.0"}
{"type":"ping","ts":"2026-04-29T12:00:00.000Z"}
{"type":"chat_message","message_id":"uuid","session_id":"default-session","content":"你好"}
```

### 服务端返回

```json
{"type":"hello_ack"}
{"type":"recording_start"}
{"type":"inference_start"}
{"type":"result","glosses":"HELLO","natural_text":"你好"}
{"type":"error","message":"service unavailable"}
{"type":"pong"}
```

## 权限与平台说明

- Android：需要相机、麦克风、网络权限。
- iOS：需要 `NSCameraUsageDescription`、`NSMicrophoneUsageDescription`、`NSSpeechRecognitionUsageDescription`。
- Web：当前使用 `takePicture()` 低频兜底采样，建议后续替换为 `getUserMedia + canvas` 自定义采帧。

## 测试方式

```bash
flutter analyze
flutter test
flutter test integration_test
```

## FAQ

### 为什么连接状态不是一启动就显示在线？

因为只有服务端返回 `hello_ack` 或 `ready` 后，前端才会进入 `connected`，避免假连接状态。

### 为什么 Web 端帧率较低？

当前 MVP 到可交付版本的过渡阶段采用保守兜底方案，优先保证稳定性和发热控制。

## Roadmap

- P0：连接重构、权限兜底、消息状态、正式首页
- P1：无障碍、平板优化、埋点与崩溃上报
- P2：Web 独立采帧、设置持久化、CI/CD
- P3：账号体系、会话历史、商业化部署
=======

