# 困困翻译助手 · macOS 全局翻译

一个 macOS 菜单栏应用：在任意 App 里用鼠标**框选**英文，选区右上方出现「译」小圆点，点一下用大模型翻译，可朗读、可加入本地生词本，还能查看学习总结。

## 功能

- 全局：在任何 App 里都能用（原生 App、Chrome/Safari 网页、邮件、备忘录、PDF、Word、聊天软件…）
- 触发：**鼠标拖动框选英文文字**，松开鼠标后选区右上角出小圆点
- 两种触发方式：默认"框选即触发"，可切到"按 Option + 框选"（避免日常选中文字误触）
- 取文字：优先用系统辅助功能 API（不动剪贴板）；AX 拿不到时自动用 Cmd+C 兜底（结束后**自动还原剪贴板**）
- 翻译：接入 DeepSeek / 通义千问 / Kimi（OpenAI 兼容协议，自定义也支持）
- 朗读：系统原生 `AVSpeechSynthesizer`，免费、不联网
- 生词本：本地 JSON 存到 `~/Library/Application Support/TranslatorApp/`
- 学习总结：基础统计 + 一键 AI 总结建议
- 隐私：API Key 存本地 UserDefaults，生词本只存本地，没有任何上传

## 项目结构

```
困困翻译助手/
├── Package.swift
└── Sources/TranslatorApp/
    ├── main.swift                 # 入口
    ├── AppDelegate.swift          # 启动装配
    ├── Permissions.swift          # 辅助功能权限
    ├── SettingsStore.swift        # 配置持久化（UserDefaults）
    ├── LLMClient.swift            # OpenAI 兼容客户端（翻译 + 总结）
    ├── VocabularyStore.swift      # 生词本本地存储（JSON）
    ├── Speaker.swift              # AVSpeechSynthesizer 朗读
    ├── SelectionReader.swift      # AX 读选中文字 + Cmd+C 兜底
    ├── SelectionDetector.swift    # CGEventTap 监听鼠标拖拽
    ├── BubbleController.swift     # 小圆点浮窗 + 翻译结果浮窗
    ├── SettingsView.swift         # 设置页 SwiftUI
    ├── VocabularyView.swift       # 生词本 SwiftUI
    ├── SummaryView.swift          # 学习总结 SwiftUI
    ├── WindowManager.swift        # 管理三个独立窗口
    └── StatusBarController.swift  # 菜单栏图标 + 菜单
```

## 怎么跑（最快验证方式：终端 `swift run`）

```bash
cd "/Users/mac/Desktop/Claude code/困困翻译助手"
swift build -c release
.build/release/TranslatorApp
```

第一次启动：

1. 系统会弹「辅助功能」权限请求，去「系统设置 → 隐私与安全性 → 辅助功能」打开 `TranslatorApp` 的开关（如果在终端里跑，会显示为 `Terminal` 或你的 IDE 名 —— 这是 SPM 跑可执行文件时的限制，下面会讲怎么打包成 `.app`）。
2. 在弹出的设置窗口里选服务商、填 API Key。各家 API Key 申请入口：
   - DeepSeek: https://platform.deepseek.com/api_keys
   - 通义千问（DashScope）：https://dashscope.console.aliyun.com/apiKey
   - Kimi（Moonshot）：https://platform.moonshot.cn/console/api-keys

## 用法

- 菜单栏会出现一个「译」字图标
- 在任意 App 里**用鼠标拖动选中**英文文字（按住左键拖一段，松开）
- 选区右上方出现紫蓝色小圆点 → 点它 → 翻译卡片弹出
- 卡片里：🔊 朗读、⭐ 加入生词本、❌ 关闭
- 想避免日常框选误触，可在设置里切到「按 Option + 框选才触发」
- 菜单栏 → 生词本 / 学习总结 / 设置

## 打包成 .app（推荐，避免每次以 Terminal 身份申请权限）

最简单的做法：用 Xcode 新建一个 macOS App 项目，把 `Sources/TranslatorApp` 里的 .swift 文件加入项目，去 `Info.plist` 加：

- `LSUIElement = YES`（不在 Dock 显示）
- `NSAppleEventsUsageDescription = 用于读取屏幕上文字以翻译`

然后 Xcode 直接编译就有 .app 了。

或者用 `swift build` 出的二进制手工打包：

```bash
APP="困困翻译助手.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/TranslatorApp "$APP/Contents/MacOS/TranslatorApp"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>困困翻译助手</string>
  <key>CFBundleIdentifier</key><string>com.local.translator</string>
  <key>CFBundleExecutable</key><string>TranslatorApp</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSAppleEventsUsageDescription</key><string>用于读取屏幕上文字以翻译</string>
</dict></plist>
PLIST
codesign --force --deep --sign - "$APP"
open "$APP"
```

## 已知限制

- **盲区**：Electron 类 App（VSCode、Slack、Notion 桌面端等）和 Canvas 渲染的内容，AX 拿不到选中文字。这种情况会用 Cmd+C 兜底（设置里可关），所以大多数情况仍可工作；但极少数 App 既不暴露 AX 也屏蔽 Cmd+C 时无解。
- **小圆点位置**：AX 支持选区 bounds 的 App 里，圆点精确出现在选区右上方；其它 App 退回到鼠标松开点附近。
- 第一次开了辅助功能权限后**必须重启 App** 才生效。
- Cmd+C 兜底会模拟一次 ⌘+C，时间在 0.1~0.4 秒，期间剪贴板会短暂被读取再还原。
- 没接联网 TTS，系统朗读音质一般。可以后续接 Edge TTS 或 ElevenLabs。

## 后续可以加

- 全局快捷键（如 ⌥⇧Space）替代鼠标点圆点
- 句子级翻译时同时输出语法解析
- 多 provider 同时配置，按场景切换
- iCloud 同步生词本
- 复习模式（间隔重复算法）
- 一键导出 Anki

## 隐私

- 翻译请求会把你悬停时读到的那段文字发到你选的 LLM 服务商
- API Key、生词本只存本地，没有任何遥测
- 源码可读，欢迎自己审计
