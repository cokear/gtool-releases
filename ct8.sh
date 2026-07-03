#!/bin/bash
export LC_ALL=C
re="\033[0m"
red="\e[1;91m"
green="\e[1;32m"
yellow="\e[1;33m"
purple="\e[1;35m"

# 彩色输出小工具
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

print_yellow "\n=== nav-dashboard 一键部署脚本 (适用于 CT8/Serv00) ===\n"

# 1. 域名配置向导
if [[ -z "$DOMAIN" ]]; then
    echo -e "${green}请输入你的自定义域名 (例如: nav.你的域名.com)${re}"
    echo -e "${yellow}👉 如果不填直接回车，将使用系统自带域名: ${DEFAULT_DOMAIN}${re}"
    read -p "输入域名: " input_domain
    if [[ -z "$input_domain" ]]; then
        CURRENT_DOMAIN="$DEFAULT_DOMAIN"
    else
        CURRENT_DOMAIN="$input_domain"
    fi
else
    CURRENT_DOMAIN="$DOMAIN"
fi

# 2. 密码配置向导
echo -e "\n${green}请设置导航站的管理后台密码 (如果不填直接回车，默认为 123456)${re}"
read -p "输入密码: " input_password
ADMIN_PASSWORD=${input_password:-123456}

WORKDIR="${HOME}/domains/${CURRENT_DOMAIN}/public_nodejs"
[[ -d "$WORKDIR" ]] && mkdir -p "$WORKDIR" && chmod 777 "$WORKDIR" >/dev/null 2>&1

command -v curl &>/dev/null && COMMAND="curl -sLo" || command -v wget &>/dev/null && COMMAND="wget -qO" || { print_red "错误: 未找到 curl 或 wget 工具。"; exit 1; }

check_website() {
    print_yellow "\n[1/5] 正在向系统底层申请 Node.js 网站环境..."
    
    CURRENT_SITE=$(devil www list | awk -v domain="$CURRENT_DOMAIN" '$1 == domain && $2 == "nodejs"')
    if [ -n "$CURRENT_SITE" ]; then
        print_green "站点 ${CURRENT_DOMAIN} 已存在 Node.js 环境，跳过创建。"
    else
        EXIST_SITE=$(devil www list | awk -v domain="$CURRENT_DOMAIN" '$1 == domain')
        if [ -n "$EXIST_SITE" ]; then
            devil www del "$CURRENT_DOMAIN" >/dev/null 2>&1
            print_yellow "已清理旧的同名站点。"
        fi
        devil www add "$CURRENT_DOMAIN" nodejs /usr/local/bin/node22 > /dev/null 2>&1
        print_green "成功创建系统级 Node.js 站点: ${CURRENT_DOMAIN}"
    fi
}

apply_configure() {
    print_yellow "\n[2/5] 正在组装 Node.js 22 全局环境..."
    ln -fs /usr/local/bin/node22 ~/bin/node > /dev/null 2>&1
    ln -fs /usr/local/bin/npm22 ~/bin/npm > /dev/null 2>&1
    mkdir -p ~/.npm-global > /dev/null 2>&1
    npm config set prefix '~/.npm-global' > /dev/null 2>&1
    
    # 临时生效当前终端
    export PATH=~/.npm-global/bin:~/bin:$PATH
    # 写入环境变量文件防丢失
    if ! grep -q "npm-global/bin" "$HOME/.bash_profile" 2>/dev/null; then
        echo 'export PATH=~/.npm-global/bin:~/bin:$PATH' >> $HOME/.bash_profile
    fi

    print_yellow "\n[3/5] 正在拉取 nav-dashboard 核心源码..."
    rm -rf "${WORKDIR:?}"/* > /dev/null 2>&1
    rm -rf "${WORKDIR:?}"/.* > /dev/null 2>&1
    cd "${WORKDIR}"
    
    # 极速下载压缩包
    $COMMAND nav-dashboard.zip https://github.com/debbide/nav-dashboard/archive/refs/heads/main.zip
    unzip -oq nav-dashboard.zip > /dev/null 2>&1
    rm -f nav-dashboard.zip
    
    # 剥离 Docker 外壳，提取纯净版 Node.js 后端代码
    mv nav-dashboard-main/docker/* ./ > /dev/null 2>&1
    mv nav-dashboard-main/docker/.* ./ 2>/dev/null
    rm -rf nav-dashboard-main
    
    # 注入用户密码和时区配置
    cat > .env <<EOF
ADMIN_PASSWORD=${ADMIN_PASSWORD}
TZ=Asia/Shanghai
EOF

    print_yellow "\n[4/5] 正在安装底层依赖模块，大概需要 1 分钟，请耐心等待..."
    npm install --silent > /dev/null 2>&1

    print_yellow "\n[5/5] 桥接启动入口，并唤醒站点..."
    # 欺骗 CT8 的守护进程，让它以为 app.js 是入口
    ln -sf server/index.js app.js
    
    # 重启站点，让代码被 Passenger 进程管理器加载
    devil www restart ${CURRENT_DOMAIN} > /dev/null 2>&1
}

show_info(){
    print_green "\n============================================="
    print_green "🎉 恭喜！导航站已成功部署并在后台隐式运行！"
    print_green "============================================="
    
    # 如果用户用了自定义域名，动态查询 IP 并给出 CF 教程
    if [[ "$CURRENT_DOMAIN" != "$DEFAULT_DOMAIN" ]]; then
        ip_address=$(devil vhost list | awk '$2 ~ /web/ {print $1}')
        print_purple "\n⚠️ 发现你使用了自定义域名！最后一步操作："
        print_purple "请前往你的域名解析商 (强烈推荐 Cloudflare)："
        print_purple "添加一条 A 记录："
        print_purple "名字: 你的域名前缀"
        print_purple "IP指向: ${yellow}${ip_address}${purple}"
        print_purple "(记得把 Cloudflare 的代理状态【小黄云】点亮，即可秒升 HTTPS)"
    fi

    echo -e "\n${green}📌 站点主页：${re}${purple}http://${CURRENT_DOMAIN}${re}"
    echo -e "${green}⚙️  管理后台：${re}${purple}http://${CURRENT_DOMAIN}/admin.html${re}"
    echo -e "${green}🔑 管理密码：${re}${purple}${ADMIN_PASSWORD}${re}\n"
    
    print_yellow "提示: 刚修改完 A 记录或者刚拉起站点，通常需要 1 分钟左右才能打开网页，稍安勿躁~"
}

# ================================
# 定义总流程并执行
# ================================
install_nav() {
    check_website
    apply_configure
    show_info
}

# 鸣枪起跑
install_nav
