#!/bin/bash
export LC_ALL=C
re="\033[0m"
red="\e[1;91m"
green="\e[1;32m"
yellow="\e[1;33m"
purple="\e[1;35m"

print_green() { echo -e "${green}$1${re}"; }
print_yellow() { echo -e "${yellow}$1${re}"; }
print_red() { echo -e "${red}$1${re}"; }
print_purple() { echo -e "${purple}$1${re}"; }

print_yellow "\n=== Node.js 版 TGBOT 专属一键原生部署脚本 (适用于 CT8/Serv00) ===\n"

# 1. 交互式填写信息
read -p "请输入你要绑定的域名 (如 bot.ct8.pl 或自定义域名): " DOMAIN
if [[ -z "$DOMAIN" ]]; then
    print_red "域名不能为空！"
    exit 1
fi

ZIP_URL="https://github.com/cokear/gtool-releases/raw/refs/heads/main/tgbot.zip"
WORKDIR="${HOME}/domains/${DOMAIN}/public_nodejs"

print_yellow "\n[1/4] 正在向系统申请原生 Node.js VIP 托管环境 (无需端口)..."
devil www del "$DOMAIN" >/dev/null 2>&1
devil www add "$DOMAIN" nodejs /usr/local/bin/node >/dev/null 2>&1
if [ $? -ne 0 ]; then
    print_red "❌ 原生 Node.js 环境配置失败！系统可能抽风，请稍后再试。"
    exit 1
fi

print_yellow "\n[2/4] 正在拉取 Node.js 代码并重构架构..."
rm -rf "$WORKDIR"/* "$WORKDIR"/.[!.]* 2>/dev/null
mkdir -p "$WORKDIR"
cd "$WORKDIR" || exit

curl -sLo bot.zip "$ZIP_URL"
unzip -oq bot.zip
mv */* ./ 2>/dev/null
mv */.* ./ 2>/dev/null
rm -rf bot.zip

# 强制将入口文件改为 app.js，迎合 Passenger 底层唤醒规则
if [ -f "index.js" ]; then
    mv index.js app.js
fi
# 兼容 Mac/Linux 不同的 sed 语法，修改 package.json 里的 main
sed -i '' 's/"main": "index.js"/"main": "app.js"/g' package.json 2>/dev/null || sed -i 's/"main": "index.js"/"main": "app.js"/g' package.json 2>/dev/null

print_yellow "\n[3/4] 正在极速安装 Node.js 依赖模块 (告别编译地狱)..."
npm install --production

print_yellow "\n[4/4] 正在唤醒 Passenger 进程守护神..."
devil www restart "$DOMAIN" >/dev/null 2>&1

print_green "\n============================================="
print_green "🎉 恭喜！Node.js 版 TGBOT 已成功获得系统 VIP 级原生托管！"
print_green "============================================="

if ! echo "$DOMAIN" | grep -q '\(ct8\.pl\|serv00\.net\|useruno\.com\)'; then
    ip_address=$(devil vhost list | awk '$2 ~ /web/ {print $1}' | head -n 1)
    print_purple "\n⚠️ 发现你使用了自定义域名！最后两步极其重要："
    print_purple "1. 去 Cloudflare 添加 A 记录，指向: ${yellow}${ip_address}${purple}"
    print_purple "2. 务必将 Cloudflare 的 SSL/TLS 加密模式改为 ${yellow}灵活 (Flexible)${purple}"
fi

print_green "\n📌 机器人管理面板：http://${DOMAIN}"
