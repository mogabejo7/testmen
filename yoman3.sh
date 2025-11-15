#!/bin/bash
# Setup otomatis Geth node + miner untuk jaringan INRI (Debian/Ubuntu generic)

set -e

# =======================
# 1. KONFIGURASI DASAR
# =======================

# FIX WALLET (tidak perlu input)
MINER_WALLET="0x98be626a1725ee2294761de540AEc88dbcb44184"

DATADIR="/root/inri"               # folder data chain
GENESIS_FILE="/root/genesis.json"  # lokasi genesis
NETWORK_ID=3777
CACHE_SIZE=2048                    # sesuaikan spek VPS
MINER_THREADS=4                    # sesuaikan vCPU
SERVICE_NAME="inri-geth"

GENESIS_URL="https://rpc.inri.life/genesis.json"
GETH_TARBALL_URL="https://gethstore.blob.core.windows.net/builds/geth-linux-amd64-1.10.26-e5eb32ac.tar.gz"


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
apt install -y curl

# =======================
# 3. CEK / INSTALL GETH (BINARY RESMI)
# =======================

if command -v geth >/dev/null 2>&1; then
  echo "✅ Geth sudah terinstall: $(geth version | head -n 1)"
else
  echo "⬇️ Geth belum ada, mendownload binary resmi..."

  TMPDIR="$(mktemp -d)"
  cd "$TMPDIR"

  echo "📥 Download: $GETH_TARBALL_URL"
  curl -fSLo geth.tar.gz "$GETH_TARBALL_URL"

  echo "📂 Extract..."
  tar -xzf geth.tar.gz

  # Cari folder geth-linux-*
  GETH_DIR="$(find . -maxdepth 1 -type d -name 'geth-linux-*' | head -n 1)"
  if [ -z "$GETH_DIR" ]; then
    echo "❌ ERROR: Folder geth-linux-* tidak ditemukan setelah extract."
    exit 1
  fi

  if [ ! -f "$GETH_DIR/geth" ]; then
    echo "❌ ERROR: Binary geth tidak ditemukan di $GETH_DIR."
    exit 1
  fi

  echo "📦 Install geth ke /usr/local/bin/geth ..."
  install -m 0755 "$GETH_DIR/geth" /usr/local/bin/geth

  cd /
  rm -rf "$TMPDIR"

  if ! command -v geth >/dev/null 2>&1; then
    echo "❌ ERROR: Geth masih belum terdeteksi setelah install."
    exit 1
  fi

  echo "✅ Geth terinstall: $(geth version | head -n 1)"
fi

# Path binary geth
GETH_BIN="$(command -v geth)"
echo "➡️ Geth binary: $GETH_BIN"
echo ""


# =======================
# 4. DOWNLOAD GENESIS
# =======================

echo "📥 Mendownload genesis INRI..."
curl -fSLo "$GENESIS_FILE" "$GENESIS_URL"
echo "✅ genesis.json tersimpan di: $GENESIS_FILE"
echo ""


# =======================
# 5. INIT DATA DIRECTORY
# =======================

echo "🧱 Menginisialisasi direktori data..."
mkdir -p "$DATADIR"
"$GETH_BIN" --datadir "$DATADIR" init "$GENESIS_FILE"
echo "✅ Init selesai"
echo ""


# =======================
# 6. SYSTEMD SERVICE
# =======================

SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}.service"

echo "📝 Membuat / overwrite systemd service..."

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
ExecStart=$GETH_BIN \\
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
# 7. START SERVICE
# =======================

echo "🔁 Reload daemon..."
systemctl daemon-reload

echo "⏹️ Stop service lama (jika ada)..."
systemctl stop "$SERVICE_NAME" 2>/dev/null || true

echo "▶️ Enable service..."
systemctl enable "$SERVICE_NAME"

echo "🚀 Start service..."
systemctl start "$SERVICE_NAME"

sleep 2

systemctl status "$SERVICE_NAME" --no-pager || true

echo ""
echo "===================================="
echo "✅ Setup selesai!"
echo "Service name : $SERVICE_NAME"
echo "Log realtime : journalctl -u $SERVICE_NAME -f"
echo "Data chain   : $DATADIR"
echo "Wallet miner : $MINER_WALLET"
echo "Binary geth  : $GETH_BIN"
echo "===================================="
echo ""
