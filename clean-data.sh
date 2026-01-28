#!/bin/bash

# 清空 data 資料夾的 script（保留 data/www/log/supervisor）
# 用於將環境恢復成初始狀態

set -e

# 顏色定義
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# 獲取 script 所在目錄
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${SCRIPT_DIR}/data"

echo -e "${YELLOW}================================${NC}"
echo -e "${YELLOW}清空 data 資料夾${NC}"
echo -e "${YELLOW}================================${NC}"
echo ""

# 檢查 data 資料夾是否存在
if [ ! -d "$DATA_DIR" ]; then
    echo -e "${RED}錯誤: data 資料夾不存在${NC}"
    exit 1
fi

# 顯示即將執行的操作
echo "即將執行以下操作："
echo -e "${RED}  1. 停止並移除所有 Docker 容器 (docker compose down)${NC}"
echo -e "${RED}  2. 清空 $DATA_DIR/mysql/* (包含隱藏檔案)${NC}"
echo -e "${RED}  3. 清空 $DATA_DIR/www/* (包含隱藏檔案)${NC}"
echo ""
echo "但會保留："
echo -e "${GREEN}  - $DATA_DIR/www/log/supervisor${NC}"
echo ""
echo -e "${RED}警告: 此操作將永久刪除資料，無法恢復！${NC}"
echo ""

# 詢問使用者確認
read -p "確定要清空 data 資料夾嗎？(yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo -e "${GREEN}已取消操作${NC}"
    exit 0
fi

# 再次確認
echo ""
echo -e "${RED}最後確認: 所有資料將被永久刪除！${NC}"
read -p "請再次輸入 'DELETE' 以確認: " FINAL_CONFIRM

if [ "$FINAL_CONFIRM" != "DELETE" ]; then
    echo -e "${GREEN}已取消操作${NC}"
    exit 0
fi

echo ""
echo "開始清空資料..."

# 停止並移除所有容器
echo "停止並移除 Docker 容器..."
cd "${SCRIPT_DIR}"
docker compose down
echo ""

# 清空 mysql 資料夾（包含隱藏檔案）
if [ -d "${DATA_DIR}/mysql" ]; then
    echo "清空 mysql 資料夾（包含隱藏檔案）..."
    sudo find "${DATA_DIR}/mysql" -mindepth 1 -delete
fi

# 清空 www 資料夾（包含隱藏檔案）
if [ -d "${DATA_DIR}/www" ]; then
    echo "清空 www 資料夾（包含隱藏檔案）..."
    sudo find "${DATA_DIR}/www" -mindepth 1 -delete
fi

# 重建 supervisor 資料夾並創建 placeholder.txt
echo "重建 supervisor 資料夾..."
sudo mkdir -p "${DATA_DIR}/www/log/supervisor"
echo "" | sudo tee "${DATA_DIR}/www/log/supervisor/placeholder.txt" > /dev/null
# Fix ownership for entire log directory to allow container to write logs
sudo chown -R $(id -u):$(id -g) "${DATA_DIR}/www/log"

echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}清空完成！${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo "data 資料夾已恢復成初始狀態"
echo "已保留: data/www/log/supervisor"
