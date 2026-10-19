#!/bin/bash
# ============================================================
#  RAG 知识库问答（rag-knowledge v2）启动脚本
#  用法：./start.sh
# ============================================================
set -u

APP_HOME="$(cd "$(dirname "$0")" && pwd)"
cd "$APP_HOME" || exit 1

PID_FILE="$APP_HOME/app.pid"
LOG_DIR="$APP_HOME/logs"
LOG_FILE="$LOG_DIR/app.log"

# JDK：宝塔上如未配置全局 java，可改成绝对路径，例如
#   JAVA_BIN=/www/server/java/jdk-17/bin/java ./start.sh
JAVA_BIN="${JAVA_BIN:-java}"

# JVM 参数，小内存服务器可把 -Xmx 调小（本应用 124 个知识块只需 300MB 左右）
JAVA_OPTS="${JAVA_OPTS:--Xms128m -Xmx512m -Dfile.encoding=UTF-8 -Duser.timezone=Asia/Shanghai}"

JAR="$(ls -1 "$APP_HOME"/*.jar 2>/dev/null | head -n 1)"
if [ -z "$JAR" ]; then
  echo "[错误] 在 $APP_HOME 下没有找到 jar 文件"
  exit 1
fi

if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "[提示] 应用已在运行，PID=$(cat "$PID_FILE")"
  exit 1
fi

mkdir -p "$LOG_DIR"

# 必须在 jar 所在目录启动：
#   data/  知识库落盘文件、config/ 外置配置、static/ 外置页面，全都按启动目录定位。
nohup "$JAVA_BIN" $JAVA_OPTS -jar "$JAR" \
  --spring.config.additional-location="optional:file:$APP_HOME/config/" \
  >> "$LOG_FILE" 2>&1 &

echo $! > "$PID_FILE"
echo "[成功] 已启动，PID=$(cat "$PID_FILE")"
echo "        日志：$LOG_FILE"
echo "        访问：http://<服务器IP>:8081/    评测页：/eval.html"
