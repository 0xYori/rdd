#!/bin/bash
#
# Skrip Instalasi Windows Otomatis untuk VPS/Server.
# Versi dengan Tampilan Proses Web di Port 80.
#

# --- Konfigurasi Awal & Pilihan OS ---
# (Untuk menambah OS, cukup tambahkan nama dan URL di bawah)
os_names=(
    "Windows 2019 Datacenter"
    "Windows 10 Super Lite (SF)"
    "Windows 10 Super Lite (MF)"
    "Windows 10 Super Lite (CF)"
    "Pakai link GZ Anda sendiri"
)
os_urls=(
    "https://sourceforge.net/projects/nixpoin/files/windows2019DO.gz"
    "https://master.dl.sourceforge.net/project/manyod/wedus10lite.gz?viasf=1"
    "https://download1582.mediafire.com/lemxvneeredgyBT5P6YtAU5Dq-mikaH29djd8VnlyMcV1iM_vHJzYCiTc8V3PQkUslqgQSG0ftRJ0X2w3t1D7T4a-616-phGqQ2xKCn8894r0fdV9jKMhVYKH8N1dXMvtsZdK6e4t9F4Hg66wCzpXvuD_jcRu9_-i65_Kbr-HeW8Bw/gcxlheshfpbyigg/wedus10lite.gz"
    "https://umbel.my.id/wedus10lite.gz"
    "custom"
)

# Direktori untuk file web
WEB_DIR="/tmp/install_progress"
mkdir -p "$WEB_DIR"

# --- Fungsi untuk Membuat Halaman HTML ---
generate_html() {
    local status_message="$1"
    local progress_bar_width="$2" # Lebar progress bar (0-100)
    local progress_text="$3" # Teks di dalam progress bar
    local auto_refresh_content="<meta http-equiv='refresh' content='3'>"

    if [[ "$status_message" == *"Selesai"* || "$status_message" == *"Gagal"* ]]; then
        auto_refresh_content=""
    fi

    cat > "$WEB_DIR/index.html" <<EOF
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    $auto_refresh_content
    <title>Proses Instalasi Windows</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #121212; color: #e0e0e0; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }
        .container { background-color: #1e1e1e; padding: 40px; border-radius: 10px; box-shadow: 0 0 20px rgba(0,0,0,0.5); width: 80%; max-width: 700px; border: 1px solid #333; }
        h1 { color: #bb86fc; text-align: center; border-bottom: 2px solid #bb86fc; padding-bottom: 10px; }
        table { width: 100%; margin-top: 20px; border-collapse: collapse; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #333; }
        th { color: #03dac6; }
        .progress-container { margin-top: 30px; background-color: #333; border-radius: 25px; padding: 5px; }
        .progress-bar { background-color: #03dac6; height: 30px; border-radius: 20px; width: ${progress_bar_width}%; transition: width 0.4s ease-in-out; display: flex; align-items: center; justify-content: center; color: #121212; font-weight: bold; }
        .footer { text-align: center; margin-top: 20px; font-size: 0.9em; color: #777; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Proses Instalasi Windows</h1>
        <table>
            <tr><th>Item</th><th>Detail</th></tr>
            <tr><td>Sistem Operasi</td><td>${os_names[$((PILIHOS-1))]}</td></tr>
            <tr><td>Alamat IP Server</td><td>${IP4}</td></tr>
            <tr><td>Status Saat Ini</td><td><b>${status_message}</b></td></tr>
        </table>
        <div class="progress-container">
            <div class="progress-bar">${progress_text}</div>
        </div>
        <div class="footer">Halaman akan refresh otomatis setiap 3 detik.</div>
    </div>
</body>
</html>
EOF
}

# --- Interaksi dengan Pengguna ---
echo "========================================="
echo "   Skrip Instalasi Windows Otomatis"
echo "========================================="
for i in "${!os_names[@]}"; do printf "   %s) %s\n" "$((i+1))" "${os_names[$i]}"; done
echo "-----------------------------------------"
read -p "Pilih OS yang ingin diinstal [1]: " PILIHOS; PILIHOS=${PILIHOS:-1}
if [[ ! "$PILIHOS" =~ ^[0-9]+$ ]] || (( PILIHOS < 1 || PILIHOS > ${#os_names[@]} )); then echo "Pilihan tidak valid."; exit 1; fi
PILIH_URL=${os_urls[$((PILIHOS-1))]}; if [[ "$PILIH_URL" == "custom" ]]; then read -p "Masukkan Link GZ kustom Anda: " PILIH_URL; fi
echo ""; read -p "Masukkan nama pengguna baru untuk Administrator (Enter untuk 'Administrator'): " NAMAADMIN; NAMAADMIN=${NAMAADMIN:-Administrator}
read -p "Masukkan password untuk akun '$NAMAADMIN': " PASSADMIN
read -p "Masukkan port RDP yang diinginkan [default: 3389]: " RDP_PORT; RDP_PORT=${RDP_PORT:-3389}
if ! [[ "$RDP_PORT" =~ ^[0-9]+$ ]] || [ "$RDP_PORT" -lt 1 ] || [ "$RDP_PORT" -gt 65535 ]; then echo "Port tidak valid."; RDP_PORT=3389; fi

# --- Pengumpulan Info & Konfigurasi Awal Web ---
echo "Mengambil informasi jaringan..."
IP4=$(curl -4 -s icanhazip.com); GW=$(ip route | awk '/default/ { print $3 }')
if [ -z "$IP4" ] || [ -z "$GW" ]; then echo "Gagal mendapatkan informasi jaringan."; exit 1; fi

# --- Pembuatan Skrip Startup Windows (net.bat & dpart.bat) ---
cat >/tmp/net.bat <<EOF
@ECHO OFF
cd.>%windir%\GetAdmin
if exist %windir%\GetAdmin (del /f /q "%windir%\GetAdmin") else (echo CreateObject^("Shell.Application"^).ShellExecute "%~s0", "%*", "", "runas", 1 >> "%temp%\Admin.vbs" & "%temp%\Admin.vbs" & del /f /q "%temp%\Admin.vbs" & exit /b 2)
wmic useraccount where name='Administrator' call rename name='$NAMAADMIN'
net user "$NAMAADMIN" "$PASSADMIN"
for /f "tokens=3*" %%i in ('netsh interface show interface ^|findstr /I /R "Local.* Ethernet Ins*"') do (set InterfaceName=%%j)
netsh -c interface ip set address name=%InterfaceName% source=static address=$IP4 mask=255.255.240.0 gateway=$GW
netsh -c interface ip add dnsservers name=%InterfaceName% address=8.8.8.8 index=1 validate=no
netsh -c interface ip add dnsservers name=%InterfaceName% address=8.8.4.4 index=2 validate=no
del /f /q "%~f0" & exit
EOF
cat >/tmp/dpart.bat <<EOF
@ECHO OFF
cd.>%windir%\GetAdmin
if exist %windir%\GetAdmin (del /f /q "%windir%\GetAdmin") else (echo CreateObject^("Shell.Application"^).ShellExecute "%~s0", "%*", "", "runas", 1 >> "%temp%\Admin.vbs" & "%temp%\Admin.vbs" & del /f /q "%temp%\Admin.vbs" & exit /b 2)
reg add "HKLM\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v PortNumber /t REG_DWORD /d $RDP_PORT /f
netsh advfirewall firewall add rule name="Open RDP Port $RDP_PORT" dir=in action=allow protocol=TCP localport=$RDP_PORT
ECHO SELECT VOLUME=%%SystemDrive%% > "%SystemDrive%\diskpart.extend" & ECHO EXTEND >> "%SystemDrive%\diskpart.extend" & START /WAIT DISKPART /S "%SystemDrive%\diskpart.extend" & del /f /q "%SystemDrive%\diskpart.extend"
del /f /q "%~f0" & timeout 20 >nul & exit
EOF

# --- Konfirmasi Akhir & Jalankan Web Server ---
echo ""
echo "==================== KONFIRMASI AKHIR ===================="
echo "  Proses instalasi dapat dipantau melalui web di:"
echo "  URL: http://${IP4}/"
echo "=========================================================="
read -p "Apakah Anda yakin ingin melanjutkan? (y/N): " KONFIRMASI
if [[ ! "$KONFIRMASI" =~ ^[yY]$ ]]; then echo "Instalasi dibatalkan."; exit; fi

# Jalankan web server di background
echo "Menjalankan web server di port 80..."
python3 -m http.server 80 --directory "$WEB_DIR" &
WEBSERVER_PID=$!

# Tulis halaman awal
generate_html "Memulai proses download..." "5" "Menunggu data..."

# --- Proses Instalasi Inti dengan Progress Update ---
echo "Memulai proses instalasi... Pantau progres di http://${IP4}/"

(wget --no-check-certificate -qO- "$PILIH_URL" | gunzip | dd of=/dev/vda bs=4M) 2>&1 | \
stdbuf -o0 tr '\r' '\n' | \
while IFS= read -r line; do
    if [[ "$line" == *"bytes"* ]]; then
        bytes=$(echo "$line" | awk '{print $1}')
        mb_copied=$(($bytes / 1024 / 1024))
        speed=$(echo "$line" | awk -F', ' '{print $3}')
        # Asumsi ukuran image maks 50GB untuk visualisasi progress bar
        progress_width=$(($mb_copied * 100 / 50000)) 
        [ $progress_width -gt 100 ] && progress_width=100
        
        generate_html "Menulis image ke disk... (${speed})" "${progress_width}" "${mb_copied} MB"
    fi
done

# Cek hasil akhir proses dd
if [ ${PIPESTATUS[2]} -eq 0 ]; then
    generate_html "✅ Selesai! Menyiapkan boot ke Windows..." "100" "Instalasi Berhasil"
    echo "Instalasi image berhasil. Menyisipkan skrip kustomisasi..."
    mount.ntfs-3g /dev/vda2 /mnt
    cp -f /tmp/net.bat "/mnt/ProgramData/Microsoft/Windows/Start Menu/Programs/Startup/net.bat"
    cp -f /tmp/dpart.bat "/mnt/ProgramData/Microsoft/Windows/Start Menu/Programs/Startup/dpart.bat"
    umount /mnt
else
    generate_html "❌ Gagal! Proses instalasi terhenti." "100" "Error"
    echo "Terjadi kesalahan saat menulis image. Silakan periksa log."
    kill $WEBSERVER_PID
    exit 1
fi

# --- Cleanup ---
rm /tmp/net.bat /tmp/dpart.bat
echo "Server akan dimatikan dalam 10 detik untuk boot ke Windows."
sleep 10
kill $WEBSERVER_PID
rm -rf "$WEB_DIR"
poweroff
