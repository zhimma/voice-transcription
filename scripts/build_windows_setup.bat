@echo off
chcp 65001 >nul
REM Windows 安装包打包脚本
REM 使用方法: .\scripts\build_windows_setup.bat [版本号]

set VERSION=%1
if "%VERSION%"=="" set VERSION=1.0.0

set APP_NAME=智能录音转写助手
set OUTPUT_DIR=build_outputs

echo 🪟 开始打包 Windows 应用...
echo 版本: %VERSION%
echo.

REM 检查 Flutter
cd frontend

REM 1. 清理旧构建
echo 🧹 清理旧构建...
call flutter clean
if errorlevel 1 (
    echo ❌ Flutter clean 失败
    exit /b 1
)

REM 2. 获取依赖
echo 📦 获取依赖...
call flutter pub get
if errorlevel 1 (
    echo ❌ 获取依赖失败
    exit /b 1
)

REM 3. 生成代码
echo 🔧 生成代码...
call flutter pub run build_runner build --delete-conflicting-outputs
if errorlevel 1 (
    echo ⚠️ 代码生成可能有警告，继续...
)

REM 4. 构建 Release 版本
echo 🔨 构建 Release 版本...
call flutter build windows --release
if errorlevel 1 (
    echo ❌ 构建失败
    exit /b 1
)

echo ✅ 构建成功
echo.

REM 5. 复制 Python 后端
echo 📁 复制 Python 后端...
if not exist "build\windows\x64\Release\bundle\python" mkdir "build\windows\x64\Release\bundle\python"
xcopy /E /I /Y "..\backend\*" "build\windows\x64\Release\bundle\python\"

REM 6. 创建输出目录
cd ..
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

REM 7. 检查 Inno Setup
echo 💿 检查 Inno Setup...
set INNO_SETUP="C:\Program Files (x86)\Inno Setup 6\ISCC.exe"

if not exist %INNO_SETUP% (
    set INNO_SETUP="C:\Program Files\Inno Setup 6\ISCC.exe"
)

if not exist %INNO_SETUP% (
    echo ⚠️ Inno Setup 未找到，尝试使用 ZIP 打包...
    
    REM 使用 PowerShell 打包 ZIP
    powershell -Command "Compress-Archive -Path 'frontend\build\windows\x64\Release\bundle\*' -DestinationPath '%OUTPUT_DIR%\VoiceTranscription-Windows-%VERSION%.zip' -Force"
    
    if exist "%OUTPUT_DIR%\VoiceTranscription-Windows-%VERSION%.zip" (
        echo ✅ ZIP 打包完成
        echo.
        echo 📦 输出文件:
        dir "%OUTPUT_DIR%\VoiceTranscription-Windows-%VERSION%.zip"
        echo.
        echo 🚀 使用方法:
        echo    解压 ZIP 文件，运行 voice_transcription.exe
    ) else (
        echo ❌ ZIP 打包失败
        exit /b 1
    )
    
    exit /b 0
)

REM 8. 使用 Inno Setup 创建安装包
echo 💿 创建安装包...
%INNO_SETUP% /Qp "scripts\build_windows_setup.iss"
if errorlevel 1 (
    echo ❌ Inno Setup 编译失败
    exit /b 1
)

REM 9. 验证输出
if exist "%OUTPUT_DIR%\VoiceTranscription-Windows-%VERSION%-Setup.exe" (
    echo.
    echo ✅ 安装包创建成功！
    echo.
    echo 📦 输出文件:
    dir "%OUTPUT_DIR%\VoiceTranscription-Windows-%VERSION%-Setup.exe"
    echo.
    echo 🚀 使用方法:
    echo    双击 Setup.exe 运行安装向导
) else (
    echo ❌ 安装包创建失败
    exit /b 1
)
