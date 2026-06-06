#!/bin/bash
apt update && apt install -y nginx certbot python3-certbot-nginx python3 python3-venv
curl -s https://raw.githubusercontent.com/Nhac-Phu-Dai-Nhan/upload-api-direct-link/main/setup.sh -o /tmp/setup.sh && chmod +x /tmp/setup.sh && bash /tmp/setup.sh
