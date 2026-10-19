#!/bin/bash
# ============================================================
#  把「本目录」（新版本）的代码更新到「现有的安装目录」
#
#  专为「已经部署过 v1，现在要升级到 v2」这个场景写的。
#
#  它只做三件事：
#    1. 备份现有安装目录的 data/ 和 config/
#    2. 停服 → 保留旧 jar 以便回滚 → 换上新 jar
#    3. 顺手更新启停脚本（如果新版本有新的）
#
#  它**绝不动**：
#    - data/knowledge-base.json   你的知识库
#    - config/application.properties  你填好的 Key 和端口
#
#  用法（先在临时目录解压新包，然后从解压出来的目录里执行）：
#      cd /www/wwwroot
#      unzip -o rag-knowledge-deploy.zip -d /tmp/rk-new
#      bash /tmp/rk-new/rag-knowledge/upgrade-install.sh /www/wwwroot/rag-knowledge
#
#  第二个参数省略时，默认目标是 /www/wwwroot/rag-knowledge
# ============================================================
set -u

NEW_HOME="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-/www/wwwroot/rag-knowledge}"

if [ ! -d "$TARGET" ]; then
  echo "[错误] 目标目录不存在：$TARGET"
  echo "       用法：bash upgrade-install.sh <现有的安装目录>"
  exit 1
fi
TARGET="$(cd "$TARGET" && pwd)"

NEW_JAR="$(ls -1 "$NEW_HOME"/*.jar 2>/dev/null | head -n 1)"
if [ -z "$NEW_JAR" ]; then
  echo "[错误] 在 $NEW_HOME 里没有找到 jar。"
  echo "       请先从 zip 解压出新版本，再从解压出来的目录里执行本脚本。"
  exit 1
fi

echo "===================== 更新安装 ====================="
echo "新版本目录：$NEW_HOME"
echo "安装目录　：$TARGET"
echo "新 jar　　：$(basename "$NEW_JAR")  ($(du -h "$NEW_JAR" | cut -f1))"
echo ""

# ---------- 1) 备份 ----------
echo "[1/5] 备份知识库与配置"
if [ -f "$TARGET/backup.sh" ]; then
  ( cd "$TARGET" && bash ./backup.sh )
else
  # 老版本没有 backup.sh，这里内联一份等价的
  BACKUP_DIR="$TARGET/backups"
  STAMP="$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$BACKUP_DIR"
  INC=""
  [ -d "$TARGET/data" ]   && INC="$INC data"
  [ -d "$TARGET/config" ] && INC="$INC config"
  if [ -n "$INC" ]; then
    ( cd "$TARGET" && tar -czf "$BACKUP_DIR/backup-$STAMP.tar.gz" $INC )
    echo "       已备份到 $BACKUP_DIR/backup-$STAMP.tar.gz"
  else
    echo "       [提示] 没有 data/ 或 config/，跳过"
  fi
fi
echo ""

# ---------- 2) 停服 ----------
echo "[2/5] 停止服务"
if [ -f "$TARGET/stop.sh" ]; then
  ( cd "$TARGET" && bash ./stop.sh ) || true
else
  echo "       [提示] 没有 stop.sh，尝试按端口结束进程"
  PID="$( (command -v ss >/dev/null && ss -lntp 2>/dev/null) | grep -oP '(?<=pid=)\d+' | head -n1 || true)"
  if [ -n "${PID:-}" ]; then kill "$PID" 2>/dev/null || true; fi
fi
sleep 2
echo ""

# ---------- 3) 替换 jar ----------
echo "[3/5] 替换 jar"
BACKUP_DIR="$TARGET/backups"
mkdir -p "$BACKUP_DIR"
for old in "$TARGET"/*.jar; do
  [ -f "$old" ] || continue
  KEEP="$BACKUP_DIR/$(basename "$old").$(date +%Y%m%d-%H%M%S).bak"
  mv "$old" "$KEEP"
  echo "       旧 jar 已留存：$KEEP"
done
cp "$NEW_JAR" "$TARGET/$(basename "$NEW_JAR")"
echo "       已放入：$TARGET/$(basename "$NEW_JAR")"
echo ""

# ---------- 4) 更新脚本与源文档（不碰 config 和 data）----------
echo "[4/5] 更新启停脚本与源文档"
for f in start.sh stop.sh restart.sh status.sh backup.sh upgrade.sh; do
  if [ -f "$NEW_HOME/$f" ]; then
    cp "$NEW_HOME/$f" "$TARGET/$f"
  fi
done
chmod +x "$TARGET"/*.sh 2>/dev/null || true
echo "       脚本已更新并加了执行权限"

if [ -d "$NEW_HOME/data/source" ]; then
  mkdir -p "$TARGET/data/source"
  cp -n "$NEW_HOME"/data/source/*.md "$TARGET/data/source/" 2>/dev/null || true
  echo "       源文档已放入 $TARGET/data/source/（$(ls -1 "$TARGET/data/source"/*.md 2>/dev/null | wc -l) 份）"
fi

# config 只在目标完全没有配置时才补一份模板，绝不覆盖已有配置
if [ ! -f "$TARGET/config/application.properties" ]; then
  mkdir -p "$TARGET/config"
  cp "$NEW_HOME/config/application.properties" "$TARGET/config/application.properties"
  echo "       [注意] 目标原来没有配置文件，已放入模板 —— 记得填 Key！"
else
  echo "       config/application.properties 已存在，保持不动（你的 Key 不会被覆盖）"
fi
echo ""

# ---------- 5) 启动 ----------
echo "[5/5] 启动服务"
if [ -f "$TARGET/start.sh" ]; then
  ( cd "$TARGET" && bash ./start.sh )
else
  echo "       [错误] 没有 start.sh，请手工启动"
  exit 1
fi
echo ""
echo "等 15 秒后检查状态…"
sleep 15
( cd "$TARGET" && bash ./status.sh )

cat <<EOF

===================== 更新完成 =====================
知识库有没有丢：看上面「知识库文件」那一行
  - 有大小数字  -> 你的旧知识库还在，没动
  - 显示"还不存在" -> 说明目标目录里本来就没有，需要重新导入文档

接下来（可选）：重建知识库拿到章节元数据
  旧知识库能直接用，但里面是没有章节信息的。
  想要像 "MySQL-知识库 > 5. 索引（高频重点） > 索引失效常见场景" 这样的定位，
  需要在页面「清空知识库」后，把 data/source/*.md 重新上传一遍。
  详见同目录下的 部署说明.md 第四节。

要回滚：
  代码  mv $TARGET/backups/*.jar.<时间戳>.bak $TARGET/rag-knowledge-0.0.1-SNAPSHOT.jar && cd $TARGET && ./restart.sh
  数据  cd $TARGET && tar -xzf backups/backup-<时间戳>.tar.gz && ./restart.sh
===================================================
EOF
