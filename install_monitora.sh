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
print_purple() { echo -e "${purple}$1${re}"; }

HOSTNAME=$(hostname)
USERNAME=$(whoami | tr '[:upper:]' '[:lower:]')

# 自动推断系统自带的默认域名
if [[ "$HOSTNAME" =~ ct8 ]]; then
    DEFAULT_DOMAIN="${USERNAME}.ct8.pl"
elif [[ "$HOSTNAME" =~ hostuno ]]; then
    DEFAULT_DOMAIN="${USERNAME}.useruno.com"
else
    DEFAULT_DOMAIN="${USERNAME}.serv00.net"
fi

print_yellow "\n=== Monitora 终极完美版一键部署脚本 (适用于 CT8/Serv00) ===\n"

# 1. 域名配置向导
echo -e "${green}请输入你要绑定的自定义域名 (例如: monitor.你的域名.com)${re}"
echo -e "${yellow}👉 如果不填直接回车，将使用系统自带域名: ${DEFAULT_DOMAIN}${re}"
read -p "输入域名: " input_domain
if [[ -z "$input_domain" ]]; then
    CURRENT_DOMAIN="$DEFAULT_DOMAIN"
else
    CURRENT_DOMAIN="$input_domain"
fi

# 你的专属最新版动态下载链接
ZIP_URL="https://github.com/debbide/monitora/releases/latest/download/monitora-release.zip"
WORKDIR="${HOME}/domains/${CURRENT_DOMAIN}/public_nodejs"

print_yellow "\n[1/5] 正在向系统底层申请 Node.js 网站环境..."
devil www del "$CURRENT_DOMAIN" >/dev/null 2>&1
devil www add "$CURRENT_DOMAIN" nodejs /usr/local/bin/node >/dev/null 2>&1
if [ $? -ne 0 ]; then
    print_red "❌ 申请环境失败！请稍后再试。"
    exit 1
fi

print_yellow "\n[2/5] 正在下载 GitHub 最新编译好的成品包..."
rm -rf "$WORKDIR" 2>/dev/null
mkdir -p "$WORKDIR"
cd "$WORKDIR" || exit 1
# 自动跟随最新版本的下载链接
curl -sLo release.zip "$ZIP_URL"
unzip -q release.zip && rm release.zip

print_yellow "\n[3/5] 正在安装生产环境极轻量依赖..."
npm ci --production --loglevel error

print_yellow "\n[4/5] 正在配置系统级启动入口..."
echo "import('./dist/server/index.js');" > app.js

print_yellow "\n[5/5] 正在唤醒系统底层守护引擎..."
devil www restart "$CURRENT_DOMAIN" >/dev/null 2>&1

print_green "\n============================================="
print_green "🎉 恭喜！Monitora 监控面板已成功部署！"
print_green "============================================="

# 只有用户填了自定义域名时，才去查 IP 并弹出提示
if [[ "$CURRENT_DOMAIN" != "$DEFAULT_DOMAIN" ]]; then
    # 用最强逻辑：直接从官方 vhost 列表提取 Web 负载均衡 IP
    ip_address=$(devil vhost list | awk '$2 ~ /web/ {print $1}' | head -n 1)
    
    print_purple "\n⚠️ 发现你使用了自定义域名！最后两步极其重要："
    print_purple "1. 去 Cloudflare 添加 A 记录，名称填域名前缀，IP 指向: ${yellow}${ip_address}${purple}"
    print_purple "2. 务必将 Cloudflare 的 SSL/TLS 加密模式改为 ${yellow}灵活 (Flexible)${purple}"
fi

echo -e "\n${green}📌 站点主页：${re}${purple}http://${CURRENT_DOMAIN}${re}\n"
