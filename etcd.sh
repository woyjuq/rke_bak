#!/usr/bin/env bash

# --- 严格模式 ---
# set -e: 任何命令失败，脚本立即退出
# set -u: 使用未定义的变量，脚本立即退出
# set -o pipefail: 管道中任意命令失败，整个管道视为失败
set -euo pipefail

BACKUP_PATH="/opt/rancher-backups"
# 备份保留天数
RETENTION_DAYS=7
RANCHER_IMAGE_NAME="rancher/rancher"
### --- 配置区结束 --- ###

# --- 日志函数 ---
log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] - $1"
}

# --- 自动查找容器名 ---
log "正在查找 $RANCHER_IMAGE_NAME 容器..."
RANCHER_CONTAINER_NAME=$(docker ps --filter "ancestor=$RANCHER_IMAGE_NAME" --format "{{.Names}}")

if [ -z "$RANCHER_CONTAINER_NAME" ]; then
  log "错误：未找到正在运行的 Rancher 容器 ($RANCHER_IMAGE_NAME)。"
  exit 1
fi
log "找到 Rancher 容器: $RANCHER_CONTAINER_NAME"

cleanup() {
  log "--- 正在执行清理/重启任务 ---"
  # 检查容器是否存在且处于停止状态
  if [ "$(docker ps -a -q -f name=^/${RANCHER_CONTAINER_NAME}$)" ] && [ "$(docker ps -q -f name=^/${RANCHER_CONTAINER_NAME}$)" == "" ]; then
     log "Rancher 处于停止状态，正在重启..."
     docker start "$RANCHER_CONTAINER_NAME"
     log "Rancher 重启成功。"
  else
     log "Rancher 正在运行 (或容器不存在)，无需重启。"
  fi
}
trap cleanup EXIT

### --- 脚本主逻辑 --- ###

log "=== Rancher 备份任务开始 ==="

# 1. 确保备份目录存在
if ! mkdir -p "$BACKUP_PATH"; then
  log "错误：无法创建备份目录 $BACKUP_PATH。请检查权限。"
  exit 1
fi
log "备份将存储在: $BACKUP_PATH"

# 2. 停止 Rancher (!!! 业务中断开始 !!!)
log "正在停止 $RANCHER_CONTAINER_NAME... (服务中断开始)"
docker stop "$RANCHER_CONTAINER_NAME"
log "Rancher 容器已停止。"

# 3. 定义备份文件名
BACKUP_FILE="rancher-data-backup-$(date '+%Y-%m-%d-%H%M').tar.gz"

# 4. 执行备份
# --volumes-from: 挂载 $RANCHER_CONTAINER_NAME 的所有卷
# -v "$BACKUP_PATH":/backup:z: 将宿主机的备份目录挂载到容器的 /backup
# --rm: 容器运行完毕后自动删除
log "正在创建备份文件: $BACKUP_FILE ..."
docker run --rm \
  --volumes-from "$RANCHER_CONTAINER_NAME" \
  -v "$BACKUP_PATH":/backup:z \
  busybox \
  tar pzcvf "/backup/$BACKUP_FILE" /var/lib/rancher

log "备份文件创建成功。"

# 5. 清理旧备份
log "正在清理 $RETENTION_DAYS 天前的旧备份..."
find "$BACKUP_PATH" -mtime "+$RETENTION_DAYS" -name "rancher-data-backup-*.tar.gz" -exec rm -f {} \;
log "旧备份清理完毕。"

log "=== Rancher 备份任务完成 ==="
# 脚本即将退出, 'trap cleanup EXIT' 将自动执行, 重启 Rancher
