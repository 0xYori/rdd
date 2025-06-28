#!/bin/bash
#
# Skrip Instalasi Windows Otomatis untuk VPS/Server.
# Versi Canggih dengan fitur keamanan, kustomisasi, dan pemilihan port RDP.
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

# Tampilan menu dinamis
echo "========================================="
echo "   Skrip Instalasi Windows Otomatis"
echo "========================================="
for i in "${!os_names[@]}"; do
    printf "   %s) %s\n" "$((i+1))" "${os_names[$i]}"
done
echo "-----------------------------------------"

read -p "Pilih OS yang ingin diinstal [1]: " PILIHOS
PILIHOS=${PILIHOS:-1} # Default pilihan adalah 1

# Validasi dan penentuan URL
if [[ ! "$PILIHOS" =~ ^[0-9]+$ ]] || (( PILIHOS < 1 || PILIHOS > ${#os_names[@]} )); then
    echo "Pilihan tidak valid. Skrip dibatalkan."
    exit 1
fi

PILIH_URL=${os_urls[$((PILIHOS-1))]}

if [[ "$PILIH_URL" == "custom" ]]; then
    read -p "Masukkan Link GZ kustom Anda: " PILIH_URL
fi

# --- Input Kredensial & Konfigurasi Kustom ---
echo ""
read -p "Masukkan nama pengguna baru untuk Administrator (Enter untuk 'Administrator'): " NAMAADMIN
NAMAADMIN=${NAMAADMIN:-Administrator}

read -p "Masukkan password untuk akun '$NAMAADMIN': " PASSADMIN

# 🆕 Meminta input port RDP dari pengguna
read -p "Masukkan port RDP yang diinginkan [default: 3389]: " RDP_PORT
RDP_PORT=${RDP_PORT:-3389} # Jika kosong, gunakan port 3389

# Validasi sederhana untuk port
if ! [[ "$RDP_PORT" =~ ^[0-9]+$ ]] || [ "$RDP_PORT" -lt 1 ] || [ "$RDP_PORT" -gt 65535 ]; then
    echo "Port tidak valid. Menggunakan port default 3389."
    RDP_PORT=3389
fi

# --- Pengumpulan Informasi Jaringan ---
echo "Mengambil informasi jaringan..."
IP4=$(curl -4 -s icanhazip.com)
GW=$(ip route | awk '/default/ { print $3 }')

if [ -z "$IP4" ] || [ -z "$GW" ]; then
    echo "Gagal mendapatkan informasi jaringan. Periksa koneksi internet."
    exit 1
fi

# --- Pembuatan Skrip Startup Windows ---

# 1. Skrip Konfigurasi Jaringan & Password (net.bat)
cat >/tmp/net.bat <<EOF
@ECHO OFF
REM Skrip untuk UAC bypass dan konfigurasi awal
cd.>%windir%\GetAdmin
if exist %windir%\GetAdmin (del /f /q "%windir%\GetAdmin") else (
    echo CreateObject^("Shell.Application"^).ShellExecute "%~s0", "%*", "", "runas", 1 >> "%temp%\Admin.vbs"
    "%temp%\Admin.vbs"
    del /f /q "%temp%\Admin.vbs"
    exit /b 2
)
REM Mengganti nama dan mengatur password Administrator
wmic useraccount where name='Administrator' call rename name='$NAMAADMIN'
net user "$NAMAADMIN" "$PASSADMIN"
REM Mengatur jaringan secara dinamis
for /f "tokens=3*" %%i in ('netsh interface show interface ^|findstr /I /R "Local.* Ethernet Ins*"') do (set InterfaceName=%%j)
netsh -c interface ip set address name=%InterfaceName% source=static address=$IP4 mask=255.255.240.0 gateway=$GW
netsh -c interface ip add dnsservers name=%InterfaceName% address=8.8.8.8 index=1 validate=no
netsh -c interface ip add dnsservers name=%InterfaceName% address=8.8.4.4 index=2 validate=no
REM Membersihkan diri dari Startup
del /f /q "%~f0"
exit
EOF

# 2. Skrip Port RDP, Partisi, & Instalasi Software (dpart.bat)
# 🆕 Variabel $RDP_PORT digunakan di sini
cat >/tmp/dpart.bat <<EOF
@ECHO OFF
echo.
echo JENDELA INI JANGAN DITUTUP. Konfigurasi RDP dan partisi sedang berjalan...
echo Setelah restart, sambungkan ke RDP menggunakan: $IP4:$RDP_PORT
echo.
REM Skrip untuk UAC bypass
cd.>%windir%\GetAdmin
if exist %windir%\GetAdmin (del /f /q "%windir%\GetAdmin") else (
    echo CreateObject^("Shell.Application"^).ShellExecute "%~s0", "%*", "", "runas", 1 >> "%temp%\Admin.vbs"
    "%temp%\Admin.vbs"
    del /f /q "%temp%\Admin.vbs"
    exit /b 2
)
REM Mengubah port RDP ke pilihan pengguna dan membuka firewall
reg add "HKLM\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v PortNumber /t REG_DWORD /d $RDP_PORT /f
netsh advfirewall firewall add rule name="Open RDP Port $RDP_PORT" dir=in action=allow protocol=TCP localport=$RDP_PORT
REM Memperluas partisi C:
ECHO SELECT VOLUME=%%SystemDrive%% > "%SystemDrive%\diskpart.extend"
ECHO EXTEND >> "%SystemDrive%\diskpart.extend"
START /WAIT DISKPART /S "%SystemDrive%\diskpart.extend"
del /f /q "%SystemDrive%\diskpart.extend"
REM Instalasi Google Chrome secara silent
echo Mengunduh dan menginstal Google Chrome...
set "chrome_installer=%TEMP%\ChromeSetup.exe"
curl -L "https://dl.google.com/chrome/install/375.122/chrome_installer.exe" -o %chrome_installer%
start /wait "" %chrome_installer% /silent /install
del /f /q %chrome_installer%
REM Membersihkan diri dari Startup
del /f /q "%~f0"
timeout 20 >nul
exit
EOF

# --- Konfirmasi Akhir & Proses Instalasi ---
echo ""
echo "==================== KONFIRMASI AKHIR ===================="
echo "  OS Pilihan:       ${os_names[$((PILIHOS-1))]}"
echo "  Target Disk:      /dev/vda"
echo "  IP Address:       $IP4"
echo "  Gateway:          $GW"
echo "  Username Admin:   $NAMAADMIN"
echo "  Port RDP Baru:    $RDP_PORT" # 🆕 Menampilkan port yang dipilih
echo ""
echo "  PERINGATAN: SEMUA DATA DI /dev/vda AKAN DIHAPUS PERMANEN!"
echo "=========================================================="
read -p "Apakah Anda yakin ingin melanjutkan? (y/N): " KONFIRMASI
if [[ ! "$KONFIRMASI" =~ ^[yY]$ ]]; then
    echo "Instalasi dibatalkan oleh pengguna."
    exit
fi

# Proses utama: download, dekompresi, dan tulis image ke disk
echo ""
echo "Memulai proses instalasi Windows. Ini akan memakan waktu lama..."
wget --no-check-certificate -qO- "$PILIH_URL" | gunzip | dd of=/dev/vda bs=4M status=progress

# Mount partisi Windows untuk menyisipkan skrip startup
echo "Menyisipkan skrip kustomisasi..."
mount.ntfs-3g /dev/vda2 /mnt

# Menyalin skrip ke folder Startup Windows
cp -f /tmp/net.bat "/mnt/ProgramData/Microsoft/Windows/Start Menu/Programs/Startup/net.bat"
cp -f /tmp/dpart.bat "/mnt/ProgramData/Microsoft/Windows/Start Menu/Programs/Startup/dpart.bat"

umount /mnt
rm /tmp/net.bat /tmp/dpart.bat

# Selesai
echo ""
echo "✅ Instalasi selesai."
echo "Server akan dimatikan dalam 5 detik untuk boot ke Windows."
sleep 5
poweroff
