#!/bin/bash
set -e

read -p "Nhap domain (vd: buianhcuong.dev): " DOMAIN
read -p "Nhap email: " EMAIL
read -p "Nhap API Key bi mat: " APIKEY

mkdir -p /var/www/files
chown -R www-data:www-data /var/www/files
chmod 755 /var/www/files

python3 -m venv /opt/upload-env
/opt/upload-env/bin/pip install flask

tee /opt/upload_api.py > /dev/null << PYEOF
from flask import Flask, request, jsonify
import os, uuid
app = Flask(__name__)
UPLOAD_DIR = "/var/www/files"
API_KEY = "$APIKEY"
@app.route("/upload", methods=["POST"])
def upload():
    if request.headers.get("X-API-Key") != API_KEY:
        return jsonify({"error": "Unauthorized"}), 401
    if "file" not in request.files:
        return jsonify({"error": "No file"}), 400
    f = request.files["file"]
    ext = os.path.splitext(f.filename)[1]
    if not ext:
        mime = f.content_type or ""
        ext = ".mp4" if "video" in mime else ".jpg"
    filename = str(uuid.uuid4()) + ext
    f.save(os.path.join(UPLOAD_DIR, filename))
    return jsonify({"url": "https://$DOMAIN/files/" + filename})
if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000)
PYEOF

tee /etc/systemd/system/upload-api.service > /dev/null << SVCEOF
[Unit]
Description=Upload API
After=network.target

[Service]
ExecStart=/opt/upload-env/bin/python3 /opt/upload_api.py
Restart=always
User=www-data
Group=www-data

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl enable upload-api
systemctl start upload-api

tee /etc/nginx/sites-available/$DOMAIN > /dev/null << NGXEOF
server {
    listen 80;
    server_name $DOMAIN;
    location /files/ {
        alias /var/www/files/;
        expires 30d;
        add_header Cache-Control "public";
    }
    location /upload {
        proxy_pass http://127.0.0.1:5000/upload;
        proxy_set_header Host \$host;
        client_max_body_size 500M;
    }
}
NGXEOF

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $EMAIL

echo "0 * * * * www-data find /var/www/files -type f -mtime +0 -delete" > /etc/cron.d/cleanup-uploads

curl -o /tmp/test.jpg "https://picsum.photos/1080/1080.jpg"
curl -X POST https://$DOMAIN/upload \
  -H "X-API-Key: $APIKEY" \
  -F "file=@/tmp/test.jpg"

echo "DONE! API chay tai https://$DOMAIN/upload"
