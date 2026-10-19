#!/bin/bash
# ============================================================
#  RAG 知识库问答（rag-knowledge v2）停止脚本
#  用法：./stop.sh
# ============================================================
set -u

APP_HOME="$(cd "$(dirname "$0")" && pwd)"
PID_FILE="$APP_HOME/app.pid"

if [ ! -f "$PID_FILE" ]; then
  echo "[提示] 未找到 $PID_FILE，应用可能不是通过 start.sh 启动的"
  exit 0
fi

PID="$(cat "$PID_FILE")"

if kill -0 "$PID" 2>/dev/null; then
  kill "$PID"
  # Spring Boot 停机时会先把知识库落盘，给它足够时间，不要一上来就 -9
  for _ in $(seq 1 30); do
    kill -0 "$PID" 2>/dev/null || break
    sleep 1
  done
  if kill -0 "$PID" 2>/dev/null; then
    echo "[警告] 优雅停止超时，强制结束 PID=$PID"
    kill -9 "$PID"
  fi
  echo "[成功] 已停止 PID=$PID"
else
  echo "[提示] 进程 $PID 不存在，清理 PID 文件"
fi

rm -f "$PID_FILE"
