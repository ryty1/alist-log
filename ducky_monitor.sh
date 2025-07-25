#!/bin/bash

echo "🚀 正在部署 DuckyCI 监控脚本..."

# 1. 安装 Python3 和 pip3
apt update
apt install -y python3 python3-pip

# 2. 安装 requests 模块
pip3 install requests

# 3. 创建脚本文件
cat << 'EOF' > /opt/ducky_monitor.py
import requests
import time
import json

TG_TOKEN = "7231458739:AAGWj2c2iENbPln1Mqq7aeFcO2-xYIc2JZc"
TG_CHAT_ID = "645346292"

DUCKY_URL = "https://api.duckyci.com/v2/compute/droplet/market/stores"
HEADERS = {
    "accept": "*/*",
    "accept-language": "zh-CN,zh;q=0.9",
    "authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJVdWlkIjoiNDM0ZDkyODU4YTQyNDk3OGFhZjQ5NGE3YTU2MjUyNjIiLCJUaW1lIjoiMTc1MzQyNDQ3NSIsImlzcyI6IkR1Y2t5IENsb3VkIEluZnJhc3RydWN0dXJlIiwic3ViIjoiVXNlciBXZWIgVG9rZW4iLCJleHAiOjE3NTYwMTY0NzUsImlhdCI6MTc1MzQyNDQ3NX0.NqpQxHC9okXPAukS2tkmWbM8ZjUdN648F4pUgSPkr_E",
    "content-type": "application/json",
    "origin": "https://next.duckyci.com",
    "referer": "https://next.duckyci.com/",
    "user-agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"
}

notified_ids = set()

def send_tg_message(msg):
    url = f"https://api.telegram.org/bot{TG_TOKEN}/sendMessage"
    data = {
        "chat_id": TG_CHAT_ID,
        "text": msg,
        "parse_mode": "Markdown",
        "disable_web_page_preview": True
    }
    try:
        r = requests.post(url, data=data, timeout=10)
        if r.status_code != 200:
            print("❌ TG 推送失败：", r.text)
    except Exception as e:
        print("❌ TG 异常：", e)

def check_market():
    try:
        resp = requests.get(DUCKY_URL, headers=HEADERS, timeout=10)
        if resp.status_code != 200:
            print(f"❌ 请求失败：{resp.status_code}")
            return

        data = resp.json()
        if not isinstance(data, list) or len(data) == 0:
            print("🔍 当前市场为空，无推送")
            return

        for item in data:
            plan_id = str(item.get("id"))
            if plan_id in notified_ids:
                continue
            title = item.get("name", "未知套餐")
            stock = item.get("stock", 0)
            msg = (
                f"📢 *DuckyCI 上架套餐！*\n\n"
                f"📛 名称：`{title}`\n"
                f"📦 库存：`{stock}`\n"
                f"🔗 [立即查看](https://next.duckyci.com)"
            )
            send_tg_message(msg)
            notified_ids.add(plan_id)
            print(f"✅ 推送套餐：{title}")

    except Exception as e:
        print("❌ 异常：", e)

if __name__ == "__main__":
    print("📡 DuckyCI 市场监控启动中...")
    while True:
        check_market()
        time.sleep(60)
EOF

# 4. 创建 systemd 服务
cat << EOF > /etc/systemd/system/ducky-monitor.service
[Unit]
Description=DuckyCI 市场监控服务
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/ducky_monitor.py
WorkingDirectory=/opt
Restart=always
RestartSec=5
StandardOutput=append:/var/log/ducky_monitor.log
StandardError=append:/var/log/ducky_monitor.log

[Install]
WantedBy=multi-user.target
EOF

# 5. 启动并设置开机自启
systemctl daemon-reload
systemctl enable --now ducky-monitor.service

echo "✅ 部署完成！服务已启动。"
echo "📄 日志文件：/var/log/ducky_monitor.log"
echo "🔍 查看状态：systemctl status ducky-monitor"
