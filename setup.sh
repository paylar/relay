#!/bin/bash

# Konfigurasi
USERNAME="toku"
PASSWORD="toku123Haxor#"
VPS_IP="109.105.194.190"
TTYD_PORT=7681
FILEBROWSER_PORT=7682

check_command() {
    if [ $? -ne 0 ]; then
        echo "Error: Gagal menjalankan perintah terakhir"
        exit 1
    fi
}

echo "Memperbarui sistem dan menginstal dependensi..."
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install -y nginx wget curl unzip

# Instal ttyd (web terminal)
echo "Menginstal ttyd..."
wget https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.x86_64 -O ttyd
check_command
chmod +x ttyd
sudo mv ttyd /usr/local/bin/

# Service ttyd dengan perbaikan input
echo "Membuat service ttyd..."
sudo tee /etc/systemd/system/ttyd.service > /dev/null <<EOL
[Unit]
Description=ttyd Service
After=network.target

[Service]
User=$USERNAME
ExecStart=/usr/local/bin/ttyd -p $TTYD_PORT -a -t enableTrzsz=true -t rendererType=canvas -t fontSize=14 -c $USERNAME:$PASSWORD /bin/bash -l
Restart=always
RestartSec=3
Environment=TERM=xterm-256color

[Install]
WantedBy=multi-user.target
EOL

# Instal FileBrowser
echo "Menginstal FileBrowser..."
FB_VERSION=$(curl -s https://api.github.com/repos/filebrowser/filebrowser/releases/latest | grep tag_name | cut -d '"' -f 4)
wget "https://github.com/filebrowser/filebrowser/releases/download/${FB_VERSION}/linux-amd64-filebrowser.tar.gz"
check_command
tar -xzf linux-amd64-filebrowser.tar.gz
chmod +x filebrowser
sudo mv filebrowser /usr/local/bin/

# Setup FileBrowser
echo "Menyiapkan FileBrowser..."
sudo mkdir -p /etc/filebrowser
sudo filebrowser config init -d /etc/filebrowser/filebrowser.db
sudo filebrowser config set -d /etc/filebrowser/filebrowser.db \
    --address 0.0.0.0 \
    --port $FILEBROWSER_PORT \
    --root /home/$USERNAME \
    --auth.method=json
sudo filebrowser users update $USERNAME -d /etc/filebrowser/filebrowser.db --password $PASSWORD

# Service FileBrowser
echo "Membuat service FileBrowser..."
sudo tee /etc/systemd/system/filebrowser.service > /dev/null <<EOL
[Unit]
Description=FileBrowser Service
After=network.target

[Service]
User=$USERNAME
ExecStart=/usr/local/bin/filebrowser -d /etc/filebrowser/filebrowser.db
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOL

# Konfigurasi Nginx dengan WebSocket fix
echo "Mengatur Nginx..."
sudo tee /etc/nginx/sites-available/web-console > /dev/null <<EOL
server {
    listen 80;
    server_name $VPS_IP;

    # Halaman utama
    location / {
        root /var/www/html;
        index index.html;
    }

    # Web Terminal
    location /terminal/ {
        proxy_pass http://127.0.0.1:$TTYD_PORT/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_buffering off;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
    }

    # File Manager
    location /files/ {
        proxy_pass http://127.0.0.1:$FILEBROWSER_PORT/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOL

# Halaman utama
echo "Membuat halaman utama..."
sudo tee /var/www/html/index.html > /dev/null <<EOL
<!DOCTYPE html>
<html>
<head>
    <title>VPS Management Console</title>
    <style>
        body { 
            font-family: Arial, sans-serif; 
            margin: 2rem; 
            background-color: #f5f5f5;
        }
        h1 { 
            color: #333; 
            text-align: center;
            margin-bottom: 2rem;
        }
        .container { 
            max-width: 800px; 
            margin: 0 auto;
            text-align: center;
        }
        .button {
            display: inline-block;
            padding: 1.5rem 3rem;
            margin: 1rem;
            background: #007bff;
            color: white;
            text-decoration: none;
            border-radius: 8px;
            font-size: 1.2rem;
            transition: transform 0.2s, box-shadow 0.2s;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        .button:hover { 
            background: #0056b3; 
            transform: translateY(-2px);
            box-shadow: 0 6px 8px rgba(0,0,0,0.2);
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🖥️ VPS Management Console</h1>
        <a href="/terminal/" class="button">🔧 Web Terminal</a>
        <a href="/files/" class="button">📁 File Manager</a>
    </div>
</body>
</html>
EOL

# Aktifkan konfigurasi
sudo ln -sf /etc/nginx/sites-available/web-console /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
check_command

# Restart layanan
echo "Me-restart layanan..."
sudo systemctl daemon-reload
sudo systemctl enable ttyd filebrowser nginx
sudo systemctl restart ttyd filebrowser nginx

# Cek status
echo "Status layanan:"
echo -n "ttyd:    "; systemctl is-active ttyd
echo -n "filebrowser: "; systemctl is-active filebrowser
echo -n "nginx:   "; systemctl is-active nginx

echo -e "\nSetup selesai!"
echo "Akses melalui: http://$VPS_IP"
echo "Username: $USERNAME"
echo "Password: $PASSWORD"