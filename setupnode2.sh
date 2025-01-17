#!/bin/bash

WSERVER_ADDR=$1
WSERVER_PORT=8765

IF="eth0"
apt update -y
apt install hping3 python3-pip bmon python3-websockets wrk siege slowhttptest apache2-utils -y
pip3 install locust==2.15.0 --break-system-packages
pip3 install itsdangerous==2.0.1 --break-system-packages
pip3 install werkzeug==2.0.3 --break-system-packages
pip install beautifulsoup4==4.12.2 --break-system-packages
pip install redis==5.0.0 --break-system-packages

curl https://raw.githubusercontent.com/sazakan/slowloris/master/slowloris.py -o /root/slowloris.py

# TRAFFIC SHAPER SCRIPT
cat <<EOF > /root/traffic_shaper.sh
#!/bin/bash
TC=/sbin/tc
IF="$IF"

# ./traffic_shaper.sh [ip_address] [MB/s]
U32="\$TC filter add dev \$IF protocol ip parent 1:0 prio 1 u32"

start() {
        bw_mb="\$2mbps"
        \$TC qdisc add dev \$IF root handle 1: htb default 30
        \$TC class add dev \$IF parent 1: classid 1:1 htb rate \$bw_mb
        \$TC class add dev \$IF parent 1: classid 1:2 htb rate \$bw_mb
        \$U32 match ip dst \$1/32 flowid 1:1
        \$U32 match ip src \$1/32 flowid 1:2
}

stop() {
        \$TC qdisc del dev \$IF root
}

case "\$1" in
        start)
                start \$2 \$3
                ;;

        stop)
                stop
                ;;

        restart)
                restart
                ;;

        *)
        ;;
esac

exit 0
EOF

chmod +x /root/traffic_shaper.sh

touch /tmp/SETUP_OK

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
            async with websockets.connect("ws://$WSERVER_ADDR:$WSERVER_PORT") as websocket:
                async for message in websocket:
                    t = threading.Thread(target=process_message, args=(message,))
                    t.start()
        except (websockets.ConnectionClosed, ConnectionRefusedError, OSError):
            print("Bağlantı kaybedildi, yeniden bağlanmaya çalışılıyor...")
            time.sleep(3)  # 3 saniye bekleyin ve yeniden deneyin

# Use asyncio.run() to run the asyncio program
if __name__ == "__main__":
    asyncio.run(client())


EOF


useradd prometheus
echo "tueeeqwe" | passwd --stdin prometheus

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
