#!/bin/bash
# ============================================================
#  备份：把「知识库」和「配置」打包存起来
#
#  为什么只需要备份这两样：
#    - jar 包随时可以从源码重新打包，不需要备份
#    - data/   里是知识库本体（已入库文档 + 向量），丢了就得重新上传文档、
#              重新花 Embedding 的额度算一遍向量
#    - config/ 里是你的 Key 和端口配置，丢了要重新填
#
#  用法：./backup.sh
# ============================================================
set -u

APP_HOME="$(cd "$(dirname "$0")" && pwd)"
cd "$APP_HOME" || exit 1

BACKUP_DIR="$APP_HOME/backups"
STAMP="$(date +%Y%m%d-%H%M%S)"
TARGET="$BACKUP_DIR/backup-$STAMP.tar.gz"

mkdir -p "$BACKUP_DIR"

INCLUDE=""
[ -d data ]   && INCLUDE="$INCLUDE data"
[ -d config ] && INCLUDE="$INCLUDE config"
[ -d static ] && INCLUDE="$INCLUDE static"

if [ -z "$INCLUDE" ]; then
  echo "[提示] 没有 data/ 或 config/ 目录，没什么可备份的"
  exit 0
fi

# shellcheck disable=SC2086
tar -czf "$TARGET" $INCLUDE

echo "[成功] 已备份到：$TARGET"
echo "        大小：$(du -h "$TARGET" | cut -f1)"
tar -tzf "$TARGET" | head -n 8 | sed 's/^/        /'
echo ""
echo "        目录里现有备份："
ls -1t "$BACKUP_DIR" | head -n 5 | sed 's/^/          /'

# 只保留最近 10 个备份，避免磁盘被撑满
COUNT="$(ls -1 "$BACKUP_DIR"/backup-*.tar.gz 2>/dev/null | wc -l)"
if [ "$COUNT" -gt 10 ]; then
  ls -1t "$BACKUP_DIR"/backup-*.tar.gz | tail -n +11 | while read -r old; do
    rm -f "$old"
    echo "        已清理旧备份：$(basename "$old")"
  done
fi
