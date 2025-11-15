#!/bin/bash

# =========================================================
# Geth Node Setup Script for INRI Network
# =========================================================

# --- 1. Konfigurasi Variabel (Ganti sesuai kebutuhan) ---

# Ganti dengan alamat dompet Anda untuk menerima hadiah mining
MINER_WALLET="0x98be626a1725ee2294761de540AEc88dbcb44184" 

# Nama file genesis dan direktori data
GENESIS_FILE="$HOME/genesis.json"
DATADIR="$HOME/inri"

# Konfigurasi Geth
NETWORK_ID=3777
CACHE_SIZE=1024 # Memory cache size in MB (e.g., 1024 for 1GB)
MINER_THREADS=4

# Bootnodes jaringan INRI
BOOTNODES="enode://5c7c744a9ac53fdb9e529743208ebd123f11c73d973aa2cf653f3ac1bdf460b6f2a9b2aec23b8f2b9d692d8c898fe0e93dac8d7533db8926924e770969f3a46a@134.199.203.8:30303,enode://f196abde38edd1db5d4208a6823fd9d5ce5823a6730c32739b9f351558f254e8d6d32b6d7a8ca43304cbcfe5c172f4a9a25defacd36eea6f5752f3b4bc01cdf@170.64.222.34:30303"

# --- 2. Perintah Setup ---

echo "⚙️ Memulai penyiapan node INRI..."

# 2.1. Download Genesis File
echo "📥 Mendownload genesis.json ke $GENESIS_FILE..."
curl -fSLo "$GENESIS_FILE" https://rpc.inri.life/genesis.json

# Cek apakah download berhasil
if [ $? -ne 0 ]; then
    echo "❌ ERROR: Gagal mendownload genesis file. Cek URL."
    exit 1
fi

# 2.2. Inisialisasi Data Directory
echo "🧱 Menginisialisasi direktori data Geth di $DATADIR..."
geth --datadir "$DATADIR" init "$GENESIS_FILE"

# Cek apakah inisialisasi berhasil
if [ $? -ne 0 ]; then
    echo "❌ ERROR: Gagal menginisialisasi Geth. Pastikan Geth sudah terinstal."
    exit 1
fi

# --- 3. Perintah Menjalankan Node dan Mining ---

echo "🚀 Menjalankan node Geth dan memulai mining..."
echo "Alamat Dompet Mining: $MINER_WALLET"

geth --datadir "$DATADIR" \
  --networkid "$NETWORK_ID" --port 30303 \
  --syncmode full --cache "$CACHE_SIZE" \
  --http --http.addr 0.0.0.0 --http.port 8545 \
  --http.api eth,net,web3,miner,txpool,admin --http.corsdomain "*" --http.vhosts "*" \
  --ws --ws.addr 0.0.0.0 --ws.port 8546 --ws.api eth,net,web3 \
  --bootnodes "$BOOTNODES" \
  --mine --miner.threads "$MINER_THREADS" --miner.etherbase "$MINER_WALLET"
