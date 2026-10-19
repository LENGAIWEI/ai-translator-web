#!/bin/bash
# ============================================================
#  状态查询
#  用法：./status.sh
# ============================================================
set -u
APP_HOME="$(cd "$(dirname "$0")" && pwd)"
PID_FILE="$APP_HOME/app.pid"
PORT="$(grep -E '^server\.port=' "$APP_HOME/config/application.properties" 2>/dev/null | tail -n1 | cut -d= -f2 | tr -d '[:space:]')"
PORT="${PORT:-8081}"

echo "===================== 运行状态 ====================="
if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  PID="$(cat "$PID_FILE")"
  echo "进程：运行中（PID=$PID）"
  echo "内存：$(ps -o rss= -p "$PID" 2>/dev/null | awk '{printf "%.0f MB", $1/1024}')"
  echo "启动于：$(ps -o lstart= -p "$PID" 2>/dev/null)"
else
  echo "进程：未运行"
fi

echo ""
echo "端口 $PORT："
if command -v ss >/dev/null 2>&1; then
  ss -lntp 2>/dev/null | grep ":$PORT " || echo "  没有监听"
else
  netstat -lntp 2>/dev/null | grep ":$PORT " || echo "  没有监听"
fi

echo ""
echo "健康检查："
if command -v curl >/dev/null 2>&1; then
  CODE="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://127.0.0.1:$PORT/kb/status" 2>/dev/null)"
  if [ "$CODE" = "200" ]; then
    echo "  /kb/status -> 200 OK"
    curl -s --max-time 5 "http://127.0.0.1:$PORT/kb/status" 2>/dev/null | head -c 400
    echo ""
  else
    echo "  /kb/status -> ${CODE:-无响应}"
  fi
else
  echo "  （没装 curl，跳过）"
fi

echo ""
echo "知识库文件："
if [ -f "$APP_HOME/data/knowledge-base.json" ]; then
  echo "  $(du -h "$APP_HOME/data/knowledge-base.json" | cut -f1)  $APP_HOME/data/knowledge-base.json"
else
  echo "  还不存在（知识库为空）"
fi
echo "===================================================="
