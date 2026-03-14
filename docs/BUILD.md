# 智能录音转写助手 - 打包构建指南

> 本文档说明如何在 Windows 和 macOS 平台上打包应用

---

## 📋 前置要求

### 必需软件

| 软件 | 版本 | 下载地址 |
|------|------|---------|
| Flutter SDK | 3.16+ | https://docs.flutter.dev/get-started/install |
| Python | 3.8+ | https://www.python.org/downloads/ |
| Git | 任意 | https://git-scm.com/downloads |

### 平台特定要求

#### macOS
- Xcode 14.0+（App Store 或 https://developer.apple.com/xcode/）
- CocoaPods（`sudo gem install cocoapods`）

#### Windows
- Visual Studio 2022（包含 C++ 桌面开发工作负载）
- Windows 10 SDK

---

## 🚀 快速打包步骤

### 1. 克隆代码

```bash
git clone https://gitlab.hulumibao.com/voice-transcription/frontend.git
cd frontend
```

### 2. 初始化平台配置

```bash
# 运行初始化脚本
./scripts/init_platforms.sh
```

或手动执行：

```bash
cd frontend

# 启用桌面支持
flutter config --enable-macos-desktop
flutter config --enable-windows-desktop

# 创建平台目录
flutter create --platforms=macos,windows .

# 安装依赖
flutter pub get

# 生成代码
flutter pub run build_runner build --delete-conflicting-outputs
```

### 3. 构建应用

#### macOS

```bash
cd frontend

# 开发调试
flutter run -d macos

# 发布构建
flutter build macos --release

# 打包 DMG
cd build/macos/Build/Products/Release
mkdir -p VoiceTranscription.app/Contents/Resources/python
cp -r ../../../../../../backend/* VoiceTranscription.app/Contents/Resources/python/
create-dmg \
  --volname "智能录音转写助手" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --app-drop-link 600 185 \
  "VoiceTranscription.dmg" \
  "voice_transcription.app"
```

#### Windows

```bash
cd frontend

# 开发调试
flutter run -d windows

# 发布构建
flutter build windows --release

# 打包（手动复制 Python 后端到输出目录）
cd build/windows/x64/Release
mkdir python
copy /Y ..\..\..\..\..\backend\* python\

# 使用 Inno Setup 创建安装包
# 1. 安装 Inno Setup: https://jrsoftware.org/isinfo.php
# 2. 创建 setup.iss 脚本
# 3. 编译生成 Setup.exe
```

#### Inno Setup 脚本示例 (setup.iss)

```pascal
[Setup]
AppName=智能录音转写助手
AppVersion=1.0.0
DefaultDirName={autopf}\VoiceTranscription
OutputDir=.
OutputBaseFilename=VoiceTranscription-Setup
Compression=lzma2
SolidCompression=yes

[Files]
Source: "build\windows\x64\Release\bundle\*"; DestDir: "{app}"; Flags: recursesubdirs
Source: "backend\*"; DestDir: "{app}\python"; Flags: recursesubdirs

[Icons]
Name: "{group}\智能录音转写助手"; Filename: "{app}\voice_transcription.exe"
Name: "{autodesktop}\智能录音转写助手"; Filename: "{app}\voice_transcription.exe"
```

---

## 📦 打包后文件结构

### macOS (.app)
```
VoiceTranscription.app/
├── Contents/
│   ├── MacOS/
│   │   └── voice_transcription    # Flutter 可执行文件
│   ├── Resources/
│   │   ├── python/               # Python 后端
│   │   │   ├── server.py
│   │   │   └── requirements.txt
│   │   └── config/               # 默认配置
│   └── Info.plist
```

### Windows (安装包)
```
VoiceTranscription/
├── voice_transcription.exe       # Flutter 可执行文件
├── python/                       # Python 后端
│   ├── server.py
│   └── requirements.txt
├── config/                       # 配置文件
└── ...                           # 依赖库
```

---

## 🔧 常见问题

### Q: macOS 构建失败 "cocoapods not installed"
```bash
sudo gem install cocoapods
```

### Q: Windows 构建失败 "Visual Studio not installed"
1. 安装 Visual Studio 2022
2. 安装 "Desktop development with C++" 工作负载
3. 重启电脑

### Q: Python 后端没有打包进去
需要手动将 `backend/` 目录复制到构建输出目录：
- macOS: `build/macos/Build/Products/Release/voice_transcription.app/Contents/Resources/python/`
- Windows: `build/windows/x64/Release/bundle/python/`

### Q: 应用启动后无法连接 Python 服务
检查 `native_service.dart` 中的 Python 路径：
```dart
// 开发环境使用相对路径
return 'python/server.py';

// 生产环境使用应用目录
return '${appDir.path}/python/server.py';
```

---

## 🐳 Docker 打包（服务端）

如果只需要 Python 后端服务：

```bash
# 构建镜像
docker build -t voice-transcription-server .

# 运行容器
docker run -d \
  --name voice-transcription \
  -p 8765:8765 \
  -v ~/.voice-transcription/models:/root/.voice-transcription/models \
  voice-transcription-server
```

---

## 📤 发布流程

1. **版本号更新**
   - 修改 `pubspec.yaml` 中的 `version`
   - 更新 `CHANGELOG.md`

2. **构建所有平台**
   ```bash
   make build-all
   ```

3. **打包分发**
   - macOS: `.dmg` 或 `.zip`
   - Windows: `.exe` 安装包
   - Linux: `.tar.gz` 或 `.AppImage`

4. **上传到 GitLab Releases**
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

---

## 📞 技术支持

- **GitLab Issues**: https://gitlab.hulumibao.com/voice-transcription/frontend/-/issues
- **Flutter 文档**: https://docs.flutter.dev/desktop
