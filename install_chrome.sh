cat << 'EOF' > /root/install_all.sh && bash /root/install_all.sh
#!/bin/bash
set -e

echo "======================================================="
echo "🚀 欢迎使用 Chrome + noVNC 一键安装脚本"
echo "======================================================="

# --- 1. 交互式收集信息 ---
echo "【安全配置】"
read -p "👉 请输入 VNC 网页访问密码 (直接回车表示不设密码): " VNC_PASS

echo ""
echo "【穿透配置】"
echo "提示：如果您想使用绑定的固定域名，请输入 CF Zero Trust 后台生成的 Token。"
read -p "👉 请输入 Cloudflare Tunnel Token (直接回车表示使用临时随机隧道): " CF_TOKEN

echo ""
echo "⏳ 开始安装，这可能需要几分钟的时间..."

echo "=== 2. 更新系统并安装基础组件 ==="
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y wget curl gnupg2 xvfb x11vnc fluxbox novnc websockify net-tools xterm 

echo "=== 3. 安装 Google Chrome ==="
wget -q -O google-chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
apt-get install -y ./google-chrome.deb || apt-get install -f -y
rm google-chrome.deb

cat << 'INNER_EOF' > /usr/local/bin/chrome-start
#!/bin/bash
/usr/bin/google-chrome --no-sandbox --user-data-dir=/root/chrome-data --window-position=0,0 --window-size=1280,800 "$@"
INNER_EOF
chmod +x /usr/local/bin/chrome-start

echo "=== 4. 安装 Cloudflared ==="
wget -q -O cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
dpkg -i cloudflared.deb || apt-get install -f -y
rm cloudflared.deb

echo "=== 5. 配置 VNC 密码与启动逻辑 ==="
VNC_PARAM="-nopw"
if [ -n "$VNC_PASS" ]; then
    mkdir -p /root/.vnc
    x11vnc -storepasswd "$VNC_PASS" /root/.vnc/passwd
    VNC_PARAM="-rfbauth /root/.vnc/passwd"
    echo "✅ 已成功设置 VNC 密码保护"
fi

cat << INNER_EOF > /root/start-desktop.sh
#!/bin/bash
export DISPLAY=:0
rm -f /tmp/.X0-lock 2>/dev/null
Xvfb :0 -screen 0 1280x800x24 &
sleep 2
fluxbox &
sleep 1
x11vnc -display :0 $VNC_PARAM -listen 127.0.0.1 -xkb -forever -shared -bg
websockify --web=/usr/share/novnc/ 8080 127.0.0.1:5900 &
sleep 2
chrome-start &
INNER_EOF
chmod +x /root/start-desktop.sh

echo "=== 6. 配置内外网穿透 ==="
if [ -n "$CF_TOKEN" ]; then
    echo "--> 收到 Token，正在注册 Cloudflare 永久系统服务..."
    cloudflared service uninstall 2>/dev/null || true
    cloudflared service install "$CF_TOKEN"
    cat << INNER_EOF > /root/start-all.sh
#!/bin/bash
/root/start-desktop.sh
echo "======================================================="
echo "🎉 桌面和穿透已启动！访问固定域名，输入密码即可进入！"
echo "======================================================="
INNER_EOF
else
    cat << 'INNER_EOF' > /root/start-all.sh
#!/bin/bash
/root/start-desktop.sh
echo "======================================================="
echo "🎉 桌面已启动！未提供 Token，正在启动临时穿透隧道..."
echo "======================================================="
cloudflared tunnel --url http://localhost:8080
INNER_EOF
fi
chmod +x /root/start-all.sh

echo ""
echo "✅ 安装配置大功告成！"
echo "👉 请运行下面这条命令来启动您的海外云电脑："
echo "   /root/start-all.sh"
EOF
