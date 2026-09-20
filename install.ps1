<#
.SYNOPSIS
    Memasang konfigurasi komorebi + whkd + YASB dari repo ini ke device saat ini.

.DESCRIPTION
    Script ini menyalin file config ke lokasi yang dibaca masing-masing tool,
    menyesuaikan path yang mengandung username Windows, lalu (opsional)
    mengunduh applications.json dan mengaktifkan autostart.

    Config lama otomatis di-backup ke folder backup/<timestamp>/ di dalam repo.

.PARAMETER SkipFetch
    Jangan unduh applications.json (pakai yang sudah ada di %USERPROFILE%).

.PARAMETER SkipAutostart
    Jangan aktifkan autostart komorebi dan YASB.

.EXAMPLE
    .\install.ps1
    .\install.ps1 -SkipAutostart
#>

[CmdletBinding()]
param(
    [switch]$SkipFetch,
    [switch]$SkipAutostart
)

$ErrorActionPreference = 'Stop'

$RepoRoot  = Split-Path -Parent $MyInvocation.MyCommand.Path
$UserHome  = $env:USERPROFILE
$ConfigDir = Join-Path $UserHome '.config'
$YasbDir   = Join-Path $ConfigDir 'yasb'
$Stamp     = Get-Date -Format 'yyyyMMdd-HHmmss'
$BackupDir = Join-Path $RepoRoot "backup\$Stamp"

function Write-Step { param([string]$Text) Write-Host "`n==> $Text" -ForegroundColor Cyan }
function Write-Ok   { param([string]$Text) Write-Host "    OK  $Text" -ForegroundColor Green }
function Write-Warn { param([string]$Text) Write-Host "    !   $Text" -ForegroundColor Yellow }

# --- 1. Cek prasyarat ------------------------------------------------------
Write-Step 'Memeriksa prasyarat'

$missing = @()
foreach ($exe in 'komorebic', 'yasbc') {
    if (-not (Get-Command $exe -ErrorAction SilentlyContinue)) { $missing += $exe }
}
if (-not (Test-Path 'C:\Program Files\whkd\bin\whkd.exe')) { $missing += 'whkd' }

if ($missing.Count -gt 0) {
    Write-Host ''
    Write-Host "Tool berikut belum terpasang / belum ada di PATH: $($missing -join ', ')" -ForegroundColor Red
    Write-Host 'Pasang dulu lewat scoop (lihat README bagian Prasyarat), lalu jalankan ulang script ini.'
    exit 1
}
Write-Ok 'komorebic, yasbc, whkd ditemukan'

# Windows 10 tidak mendukung border_implementation "Windows"
$build = [Environment]::OSVersion.Version.Build
if ($build -lt 22000) {
    Write-Ok "Windows 10 terdeteksi (build $build) - border_implementation 'Komorebi' sudah benar"
} else {
    Write-Ok "Windows 11 terdeteksi (build $build)"
}

# --- 2. Backup config lama -------------------------------------------------
Write-Step 'Mem-backup config yang ada sekarang'

$targets = @(
    @{ Src = 'komorebi\komorebi.json'; Dst = Join-Path $UserHome  'komorebi.json' }
    @{ Src = 'komorebi\whkdrc';        Dst = Join-Path $ConfigDir 'whkdrc'        }
    @{ Src = 'yasb\config.yaml';       Dst = Join-Path $YasbDir   'config.yaml'   }
    @{ Src = 'yasb\styles.css';        Dst = Join-Path $YasbDir   'styles.css'    }
)

$backedUp = 0
foreach ($t in $targets) {
    if (Test-Path $t.Dst) {
        if (-not (Test-Path $BackupDir)) { New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null }
        Copy-Item $t.Dst (Join-Path $BackupDir (Split-Path -Leaf $t.Dst)) -Force
        $backedUp++
    }
}
if ($backedUp -gt 0) { Write-Ok "$backedUp file di-backup ke backup\$Stamp\" }
else                 { Write-Ok 'Tidak ada config lama, tidak perlu backup' }

# --- 3. Salin config -------------------------------------------------------
Write-Step 'Menyalin config ke lokasinya'

foreach ($dir in $ConfigDir, $YasbDir) {
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
}

foreach ($t in $targets) {
    $src = Join-Path $RepoRoot $t.Src
    if (-not (Test-Path $src)) { throw "File repo tidak ditemukan: $($t.Src)" }
    Copy-Item $src $t.Dst -Force
    Write-Ok "$($t.Src)  ->  $($t.Dst)"
}

# --- 4. Sesuaikan path yang mengandung username ----------------------------
Write-Step 'Menyesuaikan path ke username device ini'

$HomeFwd  = $UserHome -replace '\\', '/'
$yasbConf = Join-Path $YasbDir 'config.yaml'

$content = Get-Content $yasbConf -Raw -Encoding UTF8

# Widget komorebi_control butuh path absolut ke komorebi.json
$content = [regex]::Replace(
    $content,
    'config_path:\s*"[^"]*"',
    "config_path: `"$HomeFwd/komorebi.json`""
)

# Widget wallpapers: path bawaan theme menunjuk ke folder pembuat theme
$content = [regex]::Replace(
    $content,
    'image_path:\s*"[^"]*"',
    "image_path: `"$HomeFwd/Pictures`""
)

# Tulis tanpa BOM. `Set-Content -Encoding UTF8` di Windows PowerShell 5.1
# menambahkan BOM, dan parser YAML YASB akan tersedak karenanya.
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($yasbConf, $content, $utf8NoBom)

Write-Ok "config_path -> $HomeFwd/komorebi.json"
Write-Ok "image_path  -> $HomeFwd/Pictures"

# --- 5. applications.json --------------------------------------------------
Write-Step 'Menyiapkan applications.json (aturan per-aplikasi)'

$appsJson = Join-Path $UserHome 'applications.json'
if ($SkipFetch) {
    if (Test-Path $appsJson) { Write-Ok 'Dilewati (-SkipFetch), file lama dipakai' }
    else { Write-Warn 'Dilewati (-SkipFetch) tapi applications.json TIDAK ADA - Windows Terminal dll tidak akan dikelola' }
} else {
    komorebic fetch-app-specific-configuration | Out-Null
    if (Test-Path $appsJson) {
        $count = (Get-Content $appsJson -Raw -Encoding UTF8 | ConvertFrom-Json).PSObject.Properties.Count - 1
        Write-Ok "applications.json terunduh ($count aplikasi)"
    } else {
        Write-Warn 'Unduhan gagal - jalankan manual: komorebic fetch-app-specific-configuration'
    }
}

# --- 6. Autostart ----------------------------------------------------------
if (-not $SkipAutostart) {
    Write-Step 'Mengaktifkan autostart'

    # PENTING: --config wajib ada. Tanpa itu komorebi jalan tanpa membaca
    # komorebi.json, applications.json tidak termuat, dan Windows Terminal
    # tidak akan dikelola sama sekali.
    komorebic enable-autostart --config (Join-Path $UserHome 'komorebi.json') --whkd | Out-Null
    Write-Ok 'komorebi + whkd: shortcut dibuat di shell:startup (dengan --config)'

    yasbc enable-autostart | Out-Null
    Write-Ok 'YASB: terdaftar di HKCU\...\CurrentVersion\Run'
} else {
    Write-Step 'Autostart dilewati (-SkipAutostart)'
}

# --- 7. Jalankan -----------------------------------------------------------
Write-Step 'Selesai'

Write-Host ''
Write-Host 'Jalankan sekarang dengan:' -ForegroundColor White
Write-Host "  komorebic start --config `"$UserHome\komorebi.json`" --whkd" -ForegroundColor Gray
Write-Host '  yasbc start' -ForegroundColor Gray
Write-Host ''
Write-Host 'Kalau komorebi sudah jalan, cukup reload:' -ForegroundColor White
Write-Host '  komorebic reload-configuration   (atau tekan alt+shift+o)' -ForegroundColor Gray
Write-Host '  yasbc reload' -ForegroundColor Gray
Write-Host ''
if ($backedUp -gt 0) {
    Write-Host "Config lamamu ada di: backup\$Stamp\" -ForegroundColor DarkGray
}
