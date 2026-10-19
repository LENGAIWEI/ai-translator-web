@echo off
chcp 65001 >nul
REM ============================================================
REM  本地 Windows 测试用停止脚本
REM  用法：双击，或在命令行执行 stop.bat
REM ============================================================
setlocal

echo 正在查找监听 8081 端口的 Java 进程...

set "FOUND="
for /f "tokens=5" %%p in ('netstat -ano ^| findstr ":8081" ^| findstr "LISTENING"') do (
  set "FOUND=1"
  echo   终止 PID %%p
  taskkill /PID %%p /F >nul 2>&1
)

if "%FOUND%"=="" (
  echo   [提示] 没有找到监听 8081 的进程，应用可能没在运行
) else (
  echo [成功] 已停止
)
echo.
pause
endlocal
