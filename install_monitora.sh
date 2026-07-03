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

print_yellow "\n=== Monitora 极速智能部署/无损升级脚本 ===\n"

# 1. 域名智能记忆向导
DOMAIN_CACHE="$HOME/.monitora_domain"

if [ -f "$DOMAIN_CACHE" ]; then
    CACHED_DOMAIN=$(cat "$DOMAIN_CACHE")
    read -p "请输入你要绑定的域名 (回车默认使用上次的: $CACHED_DOMAIN): " DOMAIN
    # 如果用户直接敲回车，就使用缓存的域名
    if [[ -z "$DOMAIN" ]]; then
        DOMAIN="$CACHED_DOMAIN"
    fi
else
    read -p "请输入你要绑定的域名: " DOMAIN
    if [[ -z "$DOMAIN" ]]; then
        print_red "域名不能为空！"
        exit 1
    fi
fi

# 把这次成功使用的域名记在小本本上，下次备用
echo "$DOMAIN" > "$DOMAIN_CACHE"

ZIP_URL="https://github.com/debbide/monitora/releases/latest/download/monitora-release.zip"
WORKDIR="${HOME}/domains/${DOMAIN}/public_nodejs"

# 智能判断是否需要重新申请环境
if devil www list | grep -q -w "$DOMAIN"; then
    print_yellow "\n[1/6] 站点 $DOMAIN 已存在，直接复用底层环境..."
else
    print_yellow "\n[1/6] 正在向系统申请 Node.js 环境..."
    devil www del "$DOMAIN" >/dev/null 2>&1
    devil www add "$DOMAIN" nodejs /usr/local/bin/node >/dev/null 2>&1
fi

print_yellow "\n[2/6] 正在备份历史监控数据 (如果是首次安装则跳过)..."
if [ -d "$WORKDIR/dist/data" ]; then
    print_green "发现历史数据，正在安全备份..."
    cp -r "$WORKDIR/dist/data" /tmp/monitora_data_backup
fi

print_yellow "\n[3/6] 正在下载 GitHub 最新成品包..."
rm -rf "$WORKDIR" 2>/dev/null
mkdir -p "$WORKDIR"
cd "$WORKDIR" || exit 1
curl -sLo release.zip "$ZIP_URL"
unzip -q release.zip && rm release.zip

print_yellow "\n[4/6] 正在恢复历史监控数据..."
if [ -d "/tmp/monitora_data_backup" ]; then
    mkdir -p "$WORKDIR/dist/data"
    cp -r /tmp/monitora_data_backup/* "$WORKDIR/dist/data/" 2>/dev/null
    rm -rf /tmp/monitora_data_backup
    print_green "数据恢复成功！"
fi

print_yellow "\n[5/6] 正在安装生产环境依赖..."
npm ci --production --loglevel error

print_yellow "\n[6/6] 正在配置启动入口并重启站点..."
echo "import('./dist/server/index.js');" > app.js
devil www restart "$DOMAIN" >/dev/null 2>&1

print_green "\n============================================="
print_green "✅ 部署/升级已无损完成！"
print_green "============================================="

# 提取正确的负载均衡 IP
SERVER_IP=$(devil vhost list | awk '$2 ~ /web/ {print $1}' | head -n 1)

print_purple "\n⚠️ 如果你是首次安装并使用 Cloudflare，请注意："
print_purple "1. A 记录指向 IP: ${yellow}${SERVER_IP}${purple}"
print_purple "2. SSL/TLS 模式改为: ${yellow}灵活 (Flexible)${purple}"
echo -e "\n${green}📌 站点主页：${re}${purple}http://${DOMAIN}${re}\n"
