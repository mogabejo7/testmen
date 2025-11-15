#!/bin/bash
# Full auto installer node + miner INRI
# Target: Debian/Ubuntu dengan environment tanpa systemd (pakai nohup background)

set -e

########################
# KONFIGURASI UTAMA
########################

MINER_WALLET="0x98be626a1725ee2294761de540AEc88dbcb44184"
DATADIR="/root/inri"
GENESIS_FILE="/root/genesis.json"
NETWORK_ID=3777
CACHE_SIZE=2048
MINER_THREADS=4

GENESIS_URL="https://rpc.inri.life/genesis.json"
GETH_TARBALL_URL="https://gethstore.blob.core.windows.net/builds/geth-linux-amd64-1.10.15-8be800ff.tar.gz"
RUN_SCRIPT="/root/run_inri_geth.sh"
LOG_FILE="/root/inri-geth.log"

echo "===================================="
echo "  INRI Node + Miner Installer"
echo "===================================="
echo "Wallet mining : $MINER_WALLET"
echo "Datadir       : $DATADIR"
echo "Genesis file  : $GENESIS_FILE"
echo "Log file      : $LOG_FILE"
echo "===================================="
echo ""

########################
# CEK HAK AKSES
########################

if [ "$(id -u)" -ne 0 ]; then
  echo "❌ Jalankan script ini sebagai root (sudo -i)."
  exit 1
fi

########################
# INSTALL DEPENDENCY
########################

echo "🔧 Update paket & install dependency (curl)..."
apt update -y
apt install -y curl ca-certificates

########################
# INSTALL GETH 1.10.15
########################

echo ""
echo "🔎 Mengecek apakah 'geth' sudah terinstall..."

if command -v geth >/dev/null 2>&1; then
  CURRENT_VER="$(geth version 2>/dev/null | head -n 1 || true)"
  echo "   Versi saat ini: $CURRENT_VER"
else
  CURRENT_VER="none"
  echo "   Geth belum terinstall."
fi

if echo "$CURRENT_VER" | grep -q "1.10.15"; then
  echo "✅ Geth 1.10.15 sudah terinstall, lewati instalasi."
else
  echo "⬇️  Menginstall Geth 1.10.15 ke /usr/local/bin/geth ..."
  TMPDIR="$(mktemp -d)"
  cd "$TMPDIR"

  echo "📥 Download: $GETH_TARBALL_URL"
  curl -fSLo geth.tar.gz "$GETH_TARBALL_URL"

  echo "📂 Extract..."
  tar -xzf geth.tar.gz

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

  hash -r

  echo "✅ Versi Geth sekarang:"
  geth version | head -n 3
fi

GETH_BIN="$(command -v geth)"
echo "➡️  Binary geth: $GETH_BIN"
echo ""

########################
# DOWNLOAD GENESIS
########################

echo "📥 Mendownload genesis INRI..."
curl -fSLo "$GENESIS_FILE" "$GENESIS_URL"
echo "✅ genesis.json tersimpan di: $GENESIS_FILE"
echo ""

########################
# INIT DATADIR (JIKA PERLU)
########################

echo "🔎 Mengecek datadir: $DATADIR"

if [ -d "$DATADIR/geth" ]; then
  echo "ℹ️  Datadir sudah berisi database. Skip init genesis."
else
  echo "🧱 Datadir belum ada database, melakukan init genesis..."
  mkdir -p "$DATADIR"
  "$GETH_BIN" --datadir "$DATADIR" init "$GENESIS_FILE"
  echo "✅ Init genesis selesai."
fi

echo ""

########################
# BUAT SCRIPT RUNNER
########################

echo "📝 Membuat script runner: $RUN_SCRIPT"

cat > "$RUN_SCRIPT" << EOF
#!/bin/bash

MINER_WALLET="$MINER_WALLET"
DATADIR="$DATADIR"
NETWORK_ID=$NETWORK_ID
CACHE_SIZE=$CACHE_SIZE
MINER_THREADS=$MINER_THREADS

GETH_BIN="\$(command -v geth)"

exec "\$GETH_BIN" \\
  --datadir "\$DATADIR" \\
  --networkid "\$NETWORK_ID" --port 30303 \\
  --syncmode full --cache "\$CACHE_SIZE" \\
  --http --http.addr 127.0.0.1 --http.port 8545 \\
  --http.api eth,net,web3,miner \\
  --ws --ws.addr 127.0.0.1 --ws.port 8546 --ws.api eth,net,web3 \\
  --mine --miner.threads "\$MINER_THREADS" --miner.etherbase "\$MINER_WALLET"
EOF

chmod +x "$RUN_SCRIPT"
echo "✅ Script runner siap."

########################
# STOP GETH LAMA (JIKA ADA)
########################

echo ""
echo "⏹️  Menghentikan proses geth lama (jika ada)..."
pkill geth 2>/dev/null || true
sleep 2

########################
# JALANKAN MINER DI BACKGROUND
########################

echo "🚀 Menjalankan miner INRI di background dengan nohup..."
nohup "$RUN_SCRIPT" > "$LOG_FILE" 2>&1 &

sleep 3

echo ""
echo "===================================="
echo "✅ INSTALLER SELESAI"
echo "Binary geth  : $GETH_BIN"
echo "Datadir      : $DATADIR"
echo "Wallet miner : $MINER_WALLET"
echo "Log          : $LOG_FILE"
echo "===================================="
echo ""
echo "Cek proses   : ps aux | grep geth | grep -v grep"
echo "Lihat log    : tail -f $LOG_FILE"
echo ""
echo "Kalau di log ada:"
echo "- 'Successfully sealed new block' -> mining berjalan."
echo "- 'Looking for peers peercount=0' -> belum ada peer INRI."
echo "===================================="
