#!/bin/bash
# Setup otomatis Geth node + miner untuk jaringan INRI
# Tested untuk Ubuntu/Debian (apt-based)

set -e

# =======================
# 1. KONFIGURASI DASAR
# =======================

# FIX WALLET (tidak perlu input lagi)
MINER_WALLET="0x98be626a1725ee2294761de540AEc88dbcb44184"

DATADIR="/root/inri"               # folder data chain
GENESIS_FILE="/root/genesis.json"  # lokasi genesis
NETWORK_ID=3777
CACHE_SIZE=2048                    # sesuaikan spek VPS
MINER_THREADS=4                    # sesuaikan vCPU
SERVICE_NAME="inri-geth"

GENESIS_URL="https://rpc.inri.life/genesis.json"

echo "=============================="
echo "  Setup Geth + Miner INRI"
echo "=============================="
echo "Alamat wallet mining: $MINER_WALLET"
echo ""


# =======================
# 2. CEK & INSTALL DEPENDENCY
# =======================

echo "🔧 Update paket & install dependency..."
apt update -y
apt install -y curl software-properties-common

# Install Geth
if command -v geth >/dev/null 2>&1; then
  echo "✅ Geth sudah terinstall: $(geth version | head -n 1)"
else
  echo "⬇️ Menginstall Geth..."
  add-apt-repository -y ppa:ethereum/ethereum || true
  apt update -y
  apt install -y geth
  echo "✅ Geth terinstall: $(geth version | head -n 1)"
fi


# =======================
# 3. DOWNLOAD GENESIS
# =======================

echo "📥 Mendownload genesis INRI..."
curl -fSLo "$GENESIS_FILE" "$GENESIS_URL"
echo "✅ genesis.json tersimpan di: $GENESIS_FILE"
echo ""


# =======================
# 4. INIT DATA DIRECTORY
# =======================

echo "🧱 Menginisialisasi direktori data..."
mkdir -p "$DATADIR"
geth --datadir "$DATADIR" init "$GENESIS_FILE"
echo "✅ Init selesai"
echo ""


# =======================
# 5. SYSTEMD SERVICE
# =======================

SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}.service"

echo "📝 Membuat systemd service..."

cat > "$SERVICE_PATH" <<EOF
[Unit]
Description=INRI Geth Node
After=network.target

[Service]
User=root
Group=root
Type=simple
Restart=always
RestartSec=5
ExecStart=/usr/bin/geth \\
  --datadir $DATADIR \\
  --networkid $NETWORK_ID --port 30303 \\
  --syncmode full --cache $CACHE_SIZE \\
  --http --http.addr 127.0.0.1 --http.port 8545 \\
  --http.api eth,net,web3 \\
  --ws --ws.addr 127.0.0.1 --ws.port 8546 --ws.api eth,net,web3 \\
  --bootnodes "enode://20979f6708cacc6502a64d830920a34e6a33b278c28aa7eaf773e239a9e893fe49c78b8c65b599a125195abc85ecb9a107be4a374fbd27139449e9f9faebe8d4@134.199.203.8:30303,enode://eb6f851e9789733f79281b854227087ee2db13585e854577852ed9b8ae8bb1b26f146fdb2b0701df856752f64f2492bba6a5ace585b92e3ac2028aedde1f3da2@170.64.222.34:30303" \\
  --mine --miner.threads $MINER_THREADS --miner.etherbase $MINER_WALLET

[Install]
WantedBy=multi-user.target
EOF

echo "✅ Service dibuat: $SERVICE_PATH"
echo ""


# =======================
# 6. START SERVICE
# =======================

echo "🔁 Reload daemon..."
systemctl daemon-reload

echo "▶️ Enable service..."
systemctl enable "$SERVICE_NAME"

echo "🚀 Start service..."
systemctl start "$SERVICE_NAME"

sleep 2

systemctl status "$SERVICE_NAME" --no-pager

echo ""
echo "===================================="
echo "✅ Setup selesai!"
echo "Service name : $SERVICE_NAME"
echo "Log realtime : journalctl -u $SERVICE_NAME -f"
echo "Data chain   : $DATADIR"
echo "Wallet miner : $MINER_WALLET"
echo "===================================="
echo ""
