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

print_yellow "\n=== Monitora 专属一键原生部署脚本 ===\n"

# 1. 交互式填写信息，绝不写死
read -p "请输入你要绑定的域名 (如 monitor.yourdomain.com): " DOMAIN
if [[ -z "$DOMAIN" ]]; then
    print_red "域名不能为空！"
    exit 1
fi

# 你的专属编译成品下载链接
ZIP_URL="https://github.com/debbide/monitora/releases/download/v1.0.1/monitora-release.zip"
WORKDIR="${HOME}/domains/${DOMAIN}/public_nodejs"

print_yellow "\n[1/5] 正在向系统申请原生 Node.js VIP 托管环境 (无需端口)..."
devil www del "$DOMAIN" >/dev/null 2>&1
devil www add "$DOMAIN" nodejs /usr/local/bin/node >/dev/null 2>&1
if [ $? -ne 0 ]; then
    print_red "❌ 原生 Node.js 环境配置失败！系统可能抽风，请稍后再试。"
    exit 1
fi

print_yellow "\n[2/5] 正在下载 GitHub 自动编译好的成品包..."
rm -rf "$WORKDIR" 2>/dev/null
mkdir -p "$WORKDIR"
cd "$WORKDIR" || exit 1
curl -sLo release.zip "$ZIP_URL"
unzip -q release.zip && rm release.zip

print_yellow "\n[3/5] 正在安装生产环境极轻量依赖..."
npm ci --production --loglevel error

print_yellow "\n[4/5] 正在配置系统级启动入口..."
echo "import('./dist/server/index.js');" > app.js

print_yellow "\n[5/5] 正在唤醒系统底层守护引擎..."
devil www restart "$DOMAIN"

# ================= 强制输出 IP 解析提示 =================
print_green "\n========================================================"
print_green "✅ 部署已完成！系统底层已接管进程。"
print_green "========================================================"

# 无条件获取 IP 并显示
SERVER_IP=$(devil vhost list | grep -w "$DOMAIN" | awk '{print $1}')
if [[ -z "$SERVER_IP" ]]; then
    SERVER_IP=$(curl -s ifconfig.me)
fi

print_yellow "请确保你在 Cloudflare 配置了以下解析："
print_yellow "1. 添加一条 A 记录，名称填你的域名前缀，IP 填 ${green}${SERVER_IP}${yellow}"
print_purple "2. 务必将 Cloudflare 的 SSL/TLS 加密模式改为 ${yellow}灵活 (Flexible)${purple}"
print_purple "3. 待解析生效后访问：http://${DOMAIN}"
echo ""
