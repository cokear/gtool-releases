#!/bin/bash
export LC_ALL=C
re="\033[0m"
red="\e[1;91m"
green="\e[1;32m"
yellow="\e[1;33m"

print_green() { echo -e "${green}$1${re}"; }
print_yellow() { echo -e "${yellow}$1${re}"; }
print_red() { echo -e "${red}$1${re}"; }

print_yellow "\n=== TGBOT-Python 专属一键反代部署脚本 (适用于 CT8/Serv00) ===\n"

# 1. 交互式填写信息
read -p "请输入你想绑定的域名 (如 bot.ct8.pl 或自定义域名): " DOMAIN
if [[ -z "$DOMAIN" ]]; then
    print_red "域名不能为空！"
    exit 1
fi

# 你的专属项目直链
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
# 兼容解压（不管你打包时带不带外层文件夹，都能正确提取）
mv */* ./ 2>/dev/null
mv */.* ./ 2>/dev/null
rm -rf bot.zip

print_yellow "\n[3/5] 正在创建 Python 虚拟环境并安装依赖 (这可能需要 2-3 分钟)..."
PYTHON_BIN=$(command -v python3.11 || command -v python3.10 || command -v python3)
if [ ! -d "venv" ]; then
    $PYTHON_BIN -m venv venv
fi
source venv/bin/activate
pip install -q --upgrade pip
pip install -q -r requirements.txt

print_yellow "\n[4/5] 正在设置开机自启守护 (Crontab)..."
pkill -f "$WORKDIR/venv/bin/python" >/dev/null 2>&1

CRON_CMD="@reboot cd $WORKDIR && PORT=$PORT nohup ./venv/bin/python main.py >> bot.log 2>&1 &"
(crontab -l 2>/dev/null | grep -v "$DOMAIN"; echo "$CRON_CMD") | crontab -

print_yellow "\n[5/5] 正在唤醒机器人守护进程..."
PORT=$PORT nohup ./venv/bin/python main.py >> bot.log 2>&1 &

print_green "\n============================================="
print_green "🎉 恭喜！TGBOT-Python 已成功部署并在后台隐式运行！"
print_green "============================================="
print_green "📌 机器人管理面板：http://${DOMAIN}"
print_green "💡 提示：如果使用了 Cloudflare 自定义域名，别忘了去 Cloudflare 加 A 记录，并开启【灵活(Flexible)】模式！"
