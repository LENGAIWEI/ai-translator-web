#!/bin/bash
# ============================================================
#  升级：换 jar 包，自动完成「备份 → 停服 → 替换 → 启动」
#
#  用法：
#     ./upgrade.sh /tmp/rag-knowledge-0.0.1-SNAPSHOT.jar
#
#  为什么不让你在宝塔文件管理器里直接覆盖：
#    1) 应用还在跑的时候覆盖 jar，可能读到写了一半的文件导致启动异常；
#    2) 就算覆盖成功，运行中的进程用的还是旧代码（Linux 上文件被替换后
#       进程仍持有旧 inode），不重启等于没更新；
#    3) 万一新 jar 有问题，没有旧包可以回滚。
#
#  这个脚本把这三件事都处理了，旧 jar 会留在 backups/ 里可以随时回滚。
# ============================================================
set -u

APP_HOME="$(cd "$(dirname "$0")" && pwd)"
cd "$APP_HOME" || exit 1

NEW_JAR="${1:-}"
if [ -z "$NEW_JAR" ]; then
  echo "用法：./upgrade.sh <新 jar 的路径>"
  echo "例如：./upgrade.sh /tmp/rag-knowledge-0.0.1-SNAPSHOT.jar"
  exit 1
fi

if [ ! -f "$NEW_JAR" ]; then
  echo "[错误] 找不到文件：$NEW_JAR"
  exit 1
fi

CURRENT_JAR="$(ls -1 "$APP_HOME"/*.jar 2>/dev/null | head -n 1)"

echo "===================== 升级 ====================="
echo "当前 jar：${CURRENT_JAR:-（无）}"
echo "新   jar：$NEW_JAR"
echo "大小    ：$(du -h "$NEW_JAR" | cut -f1)"
echo ""

# ---------- 1) 备份 ----------
echo "[1/4] 备份知识库与配置"
"$APP_HOME/backup.sh" || { echo "[错误] 备份失败，已中止升级"; exit 1; }
echo ""

# ---------- 2) 停服 ----------
echo "[2/4] 停止服务"
"$APP_HOME/stop.sh" || true
# 保险起见等端口释放
sleep 2
echo ""

# ---------- 3) 替换 ----------
echo "[3/4] 替换 jar"
BACKUP_DIR="$APP_HOME/backups"
mkdir -p "$BACKUP_DIR"
if [ -n "$CURRENT_JAR" ]; then
  OLD_KEEP="$BACKUP_DIR/$(basename "$CURRENT_JAR").$(date +%Y%m%d-%H%M%S).bak"
  mv "$CURRENT_JAR" "$OLD_KEEP"
  echo "        旧 jar 已留存：$OLD_KEEP"
fi
cp "$NEW_JAR" "$APP_HOME/$(basename "$NEW_JAR")"
echo "        已放入：$APP_HOME/$(basename "$NEW_JAR")"
echo ""

# ---------- 4) 启动 ----------
echo "[4/4] 启动服务"
"$APP_HOME/start.sh"
echo ""
echo "等 15 秒后检查状态（Spring Boot 启动需要几秒）…"
sleep 15
"$APP_HOME/status.sh"

cat <<'EOF'

===================== 如果启动失败 =====================
1) 先看日志：
     tail -n 100 logs/app.log

2) 要回滚到上一个版本，把 backups/ 里那个 .bak 改回 .jar 再启动：
     mv backups/rag-knowledge-0.0.1-SNAPSHOT.jar.<时间戳>.bak rag-knowledge-0.0.1-SNAPSHOT.jar
     ./restart.sh

3) 要连同数据一起回滚（数据被改坏时）：
     tar -xzf backups/backup-<时间戳>.tar.gz
     ./restart.sh
=======================================================
EOF
