#!/bin/bash
# Setup otomatis Geth node + miner untuk jaringan INRI
# Tested untuk Ubuntu/Debian (apt-based)

set -e

# =======================
# 1. KONFIGURASI DASAR
# =======================

# UBAH sesuai kebutuhan
DATADIR="/root/inri"               # folder data chain
GENESIS_FILE="/root/genesis.json"  # lokasi simpan genesis
NETWORK_ID=3777
CACHE_SIZE=2048                    # MB untuk cache Geth (sesuaikan RAM)
MINER_THREADS=4                    # jumlah thread mining (sesuaikan vCPU)
SERVICE_NAME="inri-geth"

GENESIS_URL="https://rpc.inri.life/genesis.json"

# =======================
# 2. INPUT ALAMAT WALLET
# =======================

echo "=============================="
echo "  Setup Geth + Miner INRI"
echo "=============================="
echo ""
echo "Masukkan alamat wallet EVM kamu untuk menerima reward mining (format 0x....):"
read -r MINER_WALLET

if [ -z "$MINER_WALLET" ]; then
  echo "❌ ERROR: Alamat wallet tidak boleh kosong."
  exit 1
fi

if [[ ! "$MINER_WALLET" =~ ^0x[0-9a-fA-F]{40}$ ]]; then
  echo "❌ ERROR: Format alamat wallet tidak valid. Harus seperti 0x1234... (40 hex)."
  exit 1
fi

echo ""
echo "Alamat wallet yang akan dipakai untuk mining: $MINER_WALLET"
echo ""

# =======================
# 3. CEK & INSTALL DEPENDENCY
# =======================

echo "🔧 Update paket & install dependency (curl, software-properties-common)..."
apt update -y
apt install -y curl software-properties-common

# Cek apakah geth sudah terpasang
if command -v geth >/dev/null 2>&1; then
  echo "✅ Geth sudah terinstall: $(geth version | head -n 1)"
else
  echo "⬇️  Geth belum ada, install dari PPA ethereum/ethereum..."
  add-apt-repository -y ppa:ethereum/ethereum || true
  apt update -y
  apt install -y geth

  if ! command -v geth >/dev/null 2>&1; then
    echo "❌ ERROR: Geth gagal terinstall. Cek manual."
    exit 1
  fi
  echo "✅ Geth terinstall: $(geth version | head -n 1)"
fi

# =======================
# 4. DOWNLOAD GENESIS
# =======================

echo ""
echo "📥 Mendownload genesis INRI dari: $GENESIS_URL"
curl -fSLo "$GENESIS_FILE" "$GENESIS_URL"

echo "✅ genesis.json tersimpan di: $GENESIS_FILE"
echo ""

# =======================
# 5. INIT DATADIR
# =======================

echo "🧱 Menginisialisasi direktori data Geth di $DATADIR ..."
mkdir -p "$DATADIR"
geth --datadir "$DATADIR" init "$GENESIS_FILE"
echo "✅ Init selesai."
echo ""

# =======================
# 6. BUAT SYSTEMD SERVICE
# =======================

SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}.service"

echo "📝 Membuat systemd service: $SERVICE_PATH"

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

echo "✅ Service file dibuat."

# =======================
# 7. RELOAD & START SERVICE
# =======================

echo ""
echo "🔁 Reload systemd daemon..."
systemctl daemon-reload

echo "▶️ Mengaktifkan service agar auto start saat boot..."
systemctl enable "$SERVICE_NAME"

echo "🚀 Menjalankan service sekarang..."
systemctl start "$SERVICE_NAME"

sleep 3

systemctl status "$SERVICE_NAME" --no-pager

echo ""
echo "===================================="
echo "✅ Setup selesai!"
echo "Service name : $SERVICE_NAME"
echo "Cek log      : journalctl -u $SERVICE_NAME -f"
echo "Data chain   : $DATADIR"
echo "Wallet miner : $MINER_WALLET"
echo "===================================="
echo ""
echo "Catatan:"
echo "- RPC HTTP & WS hanya listen di 127.0.0.1 (lebih aman)."
echo "- Jika mau akses dari luar, pakai SSH tunnel atau atur reverse proxy/firewall."
