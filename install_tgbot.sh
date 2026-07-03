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

print_yellow "\n=== TGBOT-Python 专属一键反代部署脚本 (适用于 CT8/Serv00) ===\n"

# 1. 交互式填写信息
read -p "请输入你想绑定的域名 (如 bot.ct8.pl 或自定义域名): " DOMAIN
if [[ -z "$DOMAIN" ]]; then
    print_red "域名不能为空！"
    exit 1
fi

ZIP_URL="https://github.com/cokear/gtool-releases/raw/refs/heads/main/py.zip"
WORKDIR="${HOME}/domains/${DOMAIN}/public_python"
mkdir -p "$WORKDIR"

print_yellow "\n[1/5] 正在向系统申请内部端口与反向代理环境..."
devil www del "$DOMAIN" >/dev/null 2>&1

PORT=$(devil port list | grep tcp | awk 'NR==1 {print $1}')
if [ -z "$PORT" ]; then
    PORT_OUTPUT=$(devil port add tcp)
    PORT=$(echo "$PORT_OUTPUT" | grep -oE "[0-9]+")
fi

if [ -z "$PORT" ]; then
    print_red "端口申请失败，可能已达到系统上限！请登录面板检查。"
    exit 1
fi
print_green " -> 成功获取专属内部端口: $PORT"

devil www add "$DOMAIN" proxy localhost "$PORT" >/dev/null 2>&1

print_yellow "\n[2/5] 正在拉取代码并清理环境..."
cd "$WORKDIR" || exit
find . -mindepth 1 -maxdepth 1 ! -name 'data' ! -name 'venv' -exec rm -rf {} +

curl -sLo bot.zip "$ZIP_URL"
unzip -oq bot.zip
mv */* ./ 2>/dev/null
mv */.* ./ 2>/dev/null
rm -rf bot.zip

print_yellow "\n[3/5] 正在创建 Python 虚拟环境并安装依赖..."
PYTHON_BIN=$(command -v python3.11 || command -v python3.10 || command -v python3)
if [ ! -d "venv" ]; then
    $PYTHON_BIN -m venv venv
fi
source venv/bin/activate
pip install -q --upgrade pip
pip install -q -r requirements.txt

print_yellow "\n[4/5] 正在配置 PM2 进程守护神..."
if ! command -v pm2 &>/dev/null; then
    npm install -g pm2 >/dev/null 2>&1
    export PATH=~/.npm-global/bin:$PATH
fi
pm2 delete "tgbot-$DOMAIN" >/dev/null 2>&1

print_yellow "\n[5/5] 正在唤醒机器人守护进程..."
PORT=$PORT pm2 start main.py --interpreter ./venv/bin/python --name "tgbot-$DOMAIN" >/dev/null 2>&1
pm2 save >/dev/null 2>&1

print_green "\n============================================="
print_green "🎉 恭喜！TGBOT-Python 已成功部署并在后台隐式运行！"
print_green "============================================="

# 自动探测并显示 IP 提示
if ! echo "$DOMAIN" | grep -q '\(ct8\.pl\|serv00\.net\|useruno\.com\)'; then
    ip_address=$(devil vhost list | awk '$2 ~ /web/ {print $1}' | head -n 1)
    print_purple "\n⚠️ 发现你使用了自定义域名！最后两步极其重要："
    print_purple "1. 去 Cloudflare 添加 A 记录，指向: ${yellow}${ip_address}${purple}"
    print_purple "2. 务必将 Cloudflare 的 SSL/TLS 加密模式改为 ${yellow}灵活 (Flexible)${purple}"
fi

print_green "\n📌 机器人管理面板：http://${DOMAIN}"
