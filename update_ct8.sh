#!/bin/bash
export LC_ALL=C
re="\033[0m"
red="\e[1;91m"
green="\e[1;32m"
yellow="\e[1;33m"
purple="\e[1;35m"

print_red() { echo -e "${red}$1${re}"; }
print_green() { echo -e "${green}$1${re}"; }
print_yellow() { echo -e "${yellow}$1${re}"; }

print_yellow "\n=== nav-dashboard 零参数无损升级脚本 (适用于 CT8/Serv00) ===\n"

# 1. 自动定位站点目录
print_green "[1/4] 正在全盘扫描已安装的导航站..."
NAV_DIR=""
for dir in ~/domains/*/public_nodejs; do
    if [ -f "$dir/server/index.js" ]; then
        NAV_DIR="$dir"
        break
    fi
done

if [ -z "$NAV_DIR" ]; then
    print_red "错误: 未找到 nav-dashboard 安装目录！请确认是否已安装。"
    exit 1
fi

DOMAIN=$(echo "$NAV_DIR" | awk -F'/' '{print $(NF-1)}')
print_green "发现目标站点: ${DOMAIN}"

# 2. 备份数据
print_yellow "\n[2/4] 正在备份核心数据(数据库和上传的图片)..."
cd "$NAV_DIR" || exit

BACKUP_DIR="/tmp/nav_backup_${DOMAIN}_$(date +%s)"
mkdir -p "$BACKUP_DIR"

if [ -d "data" ]; then
    cp -r data "$BACKUP_DIR/"
    print_green " -> 数据库文件备份成功。"
fi

if [ -d "uploads" ]; then
    cp -r uploads "$BACKUP_DIR/"
    print_green " -> 用户上传文件备份成功。"
fi

# 3. 拉取更新并覆盖
print_yellow "\n[3/4] 正在拉取最新代码并清理旧框架..."
command -v curl &>/dev/null && COMMAND="curl -sLo" || COMMAND="wget -qO"

$COMMAND nav-dashboard.zip https://github.com/debbide/nav-dashboard/archive/refs/heads/main.zip
unzip -oq nav-dashboard.zip > /dev/null 2>&1
rm -f nav-dashboard.zip

# 安全清理旧代码：除了核心数据 data, uploads, .env 以外，全删掉
find . -mindepth 1 -maxdepth 1 ! -name 'data' ! -name 'uploads' ! -name '.env' ! -name 'nav-dashboard-main' -exec rm -rf {} +

# 提取新代码
mv nav-dashboard-main/docker/* ./ > /dev/null 2>&1
mv nav-dashboard-main/docker/.* ./ 2>/dev/null
mv nav-dashboard-main/public ./ > /dev/null 2>&1
rm -rf nav-dashboard-main

# 将备份重新盖回去，确保万无一失
cp -r "$BACKUP_DIR/data" ./ 2>/dev/null
cp -r "$BACKUP_DIR/uploads" ./ 2>/dev/null
rm -rf "$BACKUP_DIR"

# 安装新代码可能带来的新依赖
npm install --silent > /dev/null 2>&1

# 4. 打补丁与重启
print_yellow "\n[4/4] 重新应用 CT8 兼容补丁并重启..."
# 补丁1：抹除写死的 0.0.0.0 IP绑定
node -e "const fs = require('fs'); let c = fs.readFileSync('server/index.js', 'utf8'); c = c.replace(/,\s*['\"](0\.0\.0\.0|127\.0\.0\.1)['\"]/g, ''); fs.writeFileSync('server/index.js', c);"
    
# 补丁2：强拆“装死”逻辑
node -e "const fs = require('fs'); let c = fs.readFileSync('server/index.js', 'utf8'); c = c.replace(/if\s*\(require\.main\s*===\s*module\)\s*\{[\s\S]*?\}/, 'startServer();'); fs.writeFileSync('server/index.js', c);"

ln -sf server/index.js app.js

devil www restart "$DOMAIN" > /dev/null 2>&1

print_green "\n============================================="
print_green "🎉 恭喜！导航站无损升级完成！"
print_green "您的网址配置、分类数据和图标已完美保留。"
print_green "=============================================\n"
