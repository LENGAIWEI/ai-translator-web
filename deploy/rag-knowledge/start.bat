@echo off
chcp 65001 >nul
REM ============================================================
REM  本地 Windows 测试用启动脚本（服务器上是 Linux，用 start.sh）
REM  用法：双击，或在命令行执行 start.bat
REM ============================================================
setlocal

cd /d "%~dp0"

set "JAVA_BIN=java"
if not "%JAVA_BIN_OVERRIDE%"=="" set "JAVA_BIN=%JAVA_BIN_OVERRIDE%"
set "JAVA_OPTS=-Xms128m -Xmx512m -Dfile.encoding=UTF-8 -Duser.timezone=Asia/Shanghai"

for %%f in ("*.jar") do set "JAR=%%f"
if "%JAR%"=="" (
  echo [错误] 当前目录下没有找到 jar 文件
  pause
  exit /b 1
)

if not exist "logs" mkdir "logs"

echo 启动 %JAR% ...
start "rag-knowledge" /b "%JAVA_BIN%" %JAVA_OPTS% -jar "%JAR%" --spring.config.additional-location="optional:file:./config/" > "logs\app.log" 2>&1

echo [成功] 已启动（后台）
echo         日志：logs\app.log
echo         访问：http://localhost:8081/    评测页：/eval.html
echo.
echo 停止请执行 stop.bat
echo.
pause
endlocal
