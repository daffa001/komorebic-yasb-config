# komorebi + YASB config

Konfigurasi tiling window manager untuk Windows: **komorebi** sebagai WM, **whkd** untuk keybinding, dan **YASB** sebagai status bar yang terintegrasi penuh dengan komorebi.

![bar](docs/bar.png)

Bar-nya memakai gaya *island* (grup melayang) dengan indikator workspace berbentuk titik yang melar jadi pill biru saat aktif — sama persis seperti widget virtual desktop bawaan YASB, tapi datanya dari komorebi.

---

## Daftar isi

1. [Fitur](#fitur)
2. [Prasyarat](#prasyarat)
3. [Struktur repo](#struktur-repo)
4. [Instalasi cepat](#instalasi-cepat)
5. [Instalasi manual](#instalasi-manual)
6. [Yang perlu disesuaikan per device](#yang-perlu-disesuaikan-per-device)
7. [Menjalankan dan reload](#menjalankan-dan-reload)
8. [Autostart](#autostart)
9. [Keybinding](#keybinding)
10. [Workspace dan layout](#workspace-dan-layout)
11. [Catatan penting](#catatan-penting)
12. [Troubleshooting](#troubleshooting)

---

## Fitur

Widget komorebi yang aktif di bar:

| Widget | Posisi | Fungsi |
|---|---|---|
| `komorebi_workspaces` | kiri | Titik workspace. Hanya workspace aktif + yang ada isinya yang tampil. Scroll di atasnya untuk pindah workspace. |
| `komorebi_active_layout` | kiri | Ikon layout aktif. **Klik kiri** buka dropdown daftar layout, **klik tengah** toggle monocle, **klik kanan** next layout. |
| `komorebi_stack` | kiri | Muncul hanya saat window sedang di-stack. Menampilkan ikon tiap window dalam stack, dibungkus border sebagai penanda. |
| `afterburner` | kiri | Suhu + load CPU dan GPU, dibaca langsung dari sensor MSI Afterburner. **Klik kiri** tukar ke tampilan detail (suhu, clock, watt), **klik kanan** buka MSI Afterburner, **hover** tooltip lengkap (VRAM, fan, RAM). Hilang otomatis saat Afterburner tidak jalan. Lihat [catatan](#widget-afterburner-membaca-shared-memory-mahm). |
| `komorebi_ctl` | kanan | Kendali komorebi dari bar lewat `scripts/komorebi-ctl.vbs`: **klik kiri** restart, **klik tengah** start, **klik kanan** stop. Menggantikan widget bawaan `komorebi_control`, yang selalu men-start komorebi non-elevated (lihat [Autostart](#varian-elevated-wajib-kalau-ada-app-yang-jalan-as-administrator)). Menu tray YASB → *Komorebi* memakai script yang sama. |
| `media` | kanan | Lagu yang sedang diputar (thumbnail + judul - artis, scroll kalau panjang), diambil dari Windows media session (Spotify, browser, VLC, ...). Hilang saat tidak ada yang diputar. **Klik kiri** popup kontrol (seek, prev/play/next, volume app), **klik tengah** play/pause, **klik kanan** judul saja. |
| `audio_visualizer` | kanan | Bar visualizer dari output audio sistem, di sebelah widget media. Hilang otomatis saat idle. |

---

## Prasyarat

### Tool

```powershell
winget install LGUG2Z.komorebi
winget install LGUG2Z.whkd
winget install AmN.yasb
```

Alternatif lewat scoop:

```powershell
scoop bucket add extras
scoop install komorebi whkd
```

Versi yang dipakai saat config ini dibuat:

| Tool | Versi | Package ID (winget) |
|---|---|---|
| komorebi | 0.1.41 | `LGUG2Z.komorebi` |
| whkd | 0.2.10 | `LGUG2Z.whkd` |
| YASB Reborn | 2.0.7 (stable) | `AmN.yasb` |
| Windows | 10 Pro 19045, 11 Pro 26200 | — |

Setelah instalasi, buka terminal **baru** supaya `komorebic` dan `yasbc` masuk ke `PATH`.

### Font (wajib, jangan dilewat)

Kalau dua font ini belum terpasang, ikon di bar akan jadi kotak kosong (*tofu*).

| Font | Dipakai untuk | Cara pasang |
|---|---|---|
| **JetBrainsMono NFP** | Ikon layout, ikon komorebi control | `winget install DEVCOM.JetBrainsMonoNerdFont` — atau `scoop bucket add nerd-fonts` lalu `scoop install JetBrainsMono-NF-Propo` |
| **Segoe Fluent Icons** | Ikon widget bawaan YASB (jam, volume, dll) | Bawaan Windows 11. Di **Windows 10 harus dipasang manual** — unduh dari [halaman Segoe Fluent Icons di Microsoft Learn](https://learn.microsoft.com/windows/apps/design/style/segoe-fluent-icons-font) |

---

## Struktur repo

| File di repo | Disalin ke |
|---|---|
| `komorebi/komorebi.json` | `%USERPROFILE%\komorebi.json` |
| `komorebi/whkdrc` | `%USERPROFILE%\.config\whkdrc` |
| `yasb/config.yaml` | `%USERPROFILE%\.config\yasb\config.yaml` |
| `yasb/styles.css` | `%USERPROFILE%\.config\yasb\styles.css` |
| `yasb/scripts/afterburner-stats.ps1` | `%USERPROFILE%\.config\yasb\scripts\afterburner-stats.ps1` |
| `scripts/install-elevated-autostart.ps1` | — (dijalankan, tidak disalin) — mendaftarkan scheduled task autostart elevated, lihat [Autostart](#autostart) |
| `scripts/komorebi-ctl.vbs` | `%USERPROFILE%\.config\komorebi-extra\komorebi-ctl.vbs` — start/stop/restart komorebi tanpa console; otomatis pakai scheduled task elevated kalau ada |

Dua file yang **sengaja tidak ikut** di-commit (lihat `.gitignore`):

- **`applications.json`** — daftar aturan per-aplikasi (±250 KB) yang dikurasi upstream. Diunduh dengan `komorebic fetch-app-specific-configuration` supaya selalu versi terbaru.
- **`yasb_colors.css`** — dibuat ulang otomatis oleh YASB tiap start, isinya warna aksen Windows.

---

## Instalasi cepat

```powershell
git clone https://github.com/daffa001/komorebic-yasb-config.git
cd komorebic-yasb-config
.\install.ps1
```

Script-nya akan: cek prasyarat → backup config lama ke `backup/<timestamp>/` → salin config → sesuaikan path username → unduh `applications.json` → aktifkan autostart.

Opsi:

```powershell
.\install.ps1 -SkipAutostart   # jangan bikin entri startup
.\install.ps1 -SkipFetch       # jangan unduh ulang applications.json
.\install.ps1 -Elevated        # autostart lewat scheduled task elevated (butuh PowerShell admin), lihat Autostart
```

Kalau PowerShell menolak menjalankan script:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

---

## Instalasi manual

Kalau lebih suka tahu persis apa yang terjadi, ikuti urutan ini.

### 1. Siapkan folder

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.config\yasb\scripts"
```

### 2. Salin config

```powershell
Copy-Item komorebi\komorebi.json "$env:USERPROFILE\komorebi.json"
Copy-Item komorebi\whkdrc        "$env:USERPROFILE\.config\whkdrc"
Copy-Item yasb\config.yaml       "$env:USERPROFILE\.config\yasb\config.yaml"
Copy-Item yasb\styles.css        "$env:USERPROFILE\.config\yasb\styles.css"
Copy-Item yasb\scripts\afterburner-stats.ps1 "$env:USERPROFILE\.config\yasb\scripts\afterburner-stats.ps1"
```

### 3. Unduh aturan per-aplikasi

```powershell
komorebic fetch-app-specific-configuration
```

Langkah ini **tidak boleh dilewat**. Tanpa `applications.json`, aplikasi multi-window seperti Windows Terminal tidak akan dikelola komorebi sama sekali.

### 4. Sesuaikan path username

Buka `%USERPROFILE%\.config\yasb\config.yaml`, ganti tiga baris ini kalau username Windows-mu bukan `daffa`:

```yaml
config_path: "C:/Users/daffa/komorebi.json"   # widget komorebi_control
image_path: "C:/Users/amn/Pictures"           # widget wallpapers

# widget afterburner - perhatikan: tanpa tanda kutip, dan path tidak boleh berspasi
run_cmd: powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File C:/Users/daffa/.config/yasb/scripts/afterburner-stats.ps1
```

### 5. Cek config terbaca

```powershell
komorebic check
```

### 6. Jalankan

```powershell
komorebic start --config "$env:USERPROFILE\komorebi.json" --whkd
yasbc start
```

### 7. Pastikan berhasil

```powershell
komorebic state | ConvertFrom-Json | ForEach-Object { $_.monitors.elements[0].workspaces.elements } |
    Where-Object { $_.containers.elements.Count -gt 0 } |
    ForEach-Object { "$($_.name): $($_.containers.elements.windows.elements.exe -join ', ')" }
```

Kalau terminalmu muncul di daftar, berarti `applications.json` termuat dengan benar.

---

## Yang perlu disesuaikan per device

| Lokasi | Nilai di repo | Kenapa perlu diubah |
|---|---|---|
| `yasb/config.yaml` → `komorebi_control.config_path` | `C:/Users/daffa/komorebi.json` | Path absolut, YASB tidak meng-expand variabel environment di sini |
| `yasb/config.yaml` → `wallpapers.image_path` | `C:/Users/amn/Pictures` | Sisa bawaan theme aslinya, arahkan ke folder gambarmu sendiri |
| `yasb/config.yaml` → `komorebi_ctl.callbacks` dan `komorebi.*_command` | `C:/Users/daffa/.config/komorebi-extra/komorebi-ctl.vbs` | Path absolut ke script kendali; sama seperti `config_path`, YASB tidak meng-expand variabel environment di callback |
| `komorebi/komorebi.json` → `monitors` | 1 monitor, 7 workspace | Tambah satu blok `monitors` lagi kalau device-nya pakai lebih dari satu layar |
| `komorebi/komorebi.json` → `layered_applications` | `claude.exe`, `Hermes.exe` | Daftar app Electron layered yang ingin di-tile; tambah/hapus sesuai app yang kamu pakai, lihat [catatan](#aplikasi-electron-dengan-ws_ex_layered-claude-desktop-diabaikan-komorebi) |
| `yasb/config.yaml` → `afterburner.exec_options.run_cmd` | `C:/Users/daffa/.config/yasb/scripts/afterburner-stats.ps1` | Path absolut ke script pembaca sensor, alasan yang sama dengan `config_path` |

`install.ps1` menangani semua path username secara otomatis. Hanya `monitors` dan `layered_applications` yang harus manual.

> `komorebi.json` memakai `$Env:USERPROFILE/applications.json`, jadi **itu** sudah portabel dan tidak perlu diubah.

---

## Menjalankan dan reload

| Tujuan | Perintah |
|---|---|
| Start komorebi + whkd | `komorebic start --config "$env:USERPROFILE\komorebi.json" --whkd` |
| Start bar | `yasbc start` |
| **Reload komorebi** (tanpa restart) | `komorebic reload-configuration` — atau tekan `alt + shift + o` |
| Reload bar | `yasbc reload` |
| Stop semua | `komorebic stop --whkd` lalu `yasbc stop` |

Restart penuh (stop + start, dengan elevation yang benar) bisa lewat widget `komorebi_ctl` di bar (klik kiri ikon komorebi di kanan) atau menu tray YASB → *Komorebi*. Keduanya menjalankan `scripts/komorebi-ctl.vbs`.

---

## Autostart

```powershell
komorebic enable-autostart --config "$env:USERPROFILE\komorebi.json" --whkd
yasbc enable-autostart
```

Yang terjadi:

- **komorebi** → shortcut `komorebi.lnk` di `shell:startup`, dengan `--config` sudah tertanam di argumennya dan whkd ikut dijalankan.
- **YASB** → entri `YASB` di `HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run` (bukan shortcut, jadi jangan dicari di folder Startup).

Urutan start tidak perlu diatur — widget komorebi di YASB memakai named pipe dan menunggu komorebi menyambung sendiri.

Membatalkan:

```powershell
komorebic disable-autostart
yasbc disable-autostart
```

### Varian elevated (wajib kalau ada app yang jalan as Administrator)

Kalau kamu menjalankan Windows Terminal, VS Code, atau aplikasi lain **sebagai Administrator**, komorebi yang dijalankan lewat shortcut startup biasa (non-elevated) **tidak akan pernah mengelola window itu** — lihat [catatan](#aplikasi-yang-jalan-sebagai-administrator-tidak-ter-tile). Solusinya komorebi harus ikut elevated, dan satu-satunya cara autostart elevated tanpa prompt UAC tiap login adalah scheduled task dengan *Run with highest privileges*.

```powershell
# dari PowerShell yang dijalankan sebagai Administrator
.\scripts\install-elevated-autostart.ps1
# atau sekaligus saat instalasi:
.\install.ps1 -Elevated
```

Script-nya:

- mendaftarkan task **`komorebi Elevated Autostart`** — trigger *At log on* (+5 detik), *Run with highest privileges*, aksi `komorebic-no-console.exe start --config "%USERPROFILE%\komorebi.json" --whkd`;
- menghapus `komorebi.lnk` di `shell:startup` supaya tidak ada instance kedua yang non-elevated;
- menghapus task `FancyWM Elevated Autostart` kalau masih ada (sisa WM lama).

whkd ikut elevated karena di-spawn oleh komorebic dari dalam task itu. YASB tetap non-elevated dan tidak perlu diubah — komunikasi ke komorebi lewat named pipe/socket tidak terpengaruh.

Restart manual tanpa reboot:

```powershell
komorebic stop --whkd
schtasks /run /tn "komorebi Elevated Autostart"
```

> Widget bawaan YASB `komorebi_control` menjalankan `komorebic start` **sebagai user biasa** (non-elevated), jadi pada setup elevated tombol Start/Reload-nya justru merusak: komorebi elevated dihentikan lalu diganti instance non-elevated, Terminal/VS Code langsung lepas dari tiling. Karena itu config ini memakai widget custom `komorebi_ctl` + menu tray yang memanggil `scripts/komorebi-ctl.vbs` — script itu mendeteksi task elevated dan men-start lewat `schtasks /run`. Kalau komorebi sempat jalan non-elevated, cukup klik kiri widget `komorebi_ctl` (restart); window yang sempat lepas perlu minimize/restore.

Membatalkan:

```powershell
Unregister-ScheduledTask -TaskName 'komorebi Elevated Autostart' -Confirm:$false
```

---

## Keybinding

Semua diatur di `komorebi/whkdrc`. Prefix-nya `alt`.

### Fokus dan pindah window

| Tombol | Aksi |
|---|---|
| `alt + h / j / k / l` | Pindah fokus kiri / bawah / atas / kanan |
| `alt + shift + h / j / k / l` | Geser window ke arah tersebut |
| `alt + shift + [ / ]` | Cycle fokus ke window sebelumnya / berikutnya |
| `alt + shift + enter` | Jadikan window aktif sebagai window utama |
| `alt + q` | Tutup window |
| `alt + m` | Minimize |

### Stack

| Tombol | Aksi |
|---|---|
| `alt + ← / ↓ / ↑ / →` | Stack window ke arah tersebut |
| `alt + ;` | Keluarkan window dari stack |
| `alt + `` ` `` / `]` | Pindah ke window sebelumnya / berikutnya di dalam stack |

### Layout dan ukuran

| Tombol | Aksi |
|---|---|
| `alt + = / -` | Perbesar / perkecil lebar |
| `alt + shift + = / -` | Perbesar / perkecil tinggi |
| `alt + x` | Flip layout horizontal |
| `alt + y` | Flip layout vertikal |
| `alt + t` | Toggle floating |
| `alt + shift + f` | Toggle monocle (fullscreen dalam tiling) |
| `alt + shift + r` | Retile paksa |
| `alt + p` | Pause komorebi |

### Workspace

| Tombol | Aksi |
|---|---|
| `alt + 1` … `alt + 8` | Pindah ke workspace 1–8 |
| `alt + shift + 1` … `alt + shift + 8` | Pindahkan window ke workspace 1–8 |

> Config ini mendefinisikan 7 workspace. `alt + 8` tetap berfungsi — komorebi membuat workspace ke-8 secara otomatis dengan layout default.

### Lain-lain

| Tombol | Aksi |
|---|---|
| `alt + shift + o` | Reload config komorebi |
| `alt + o` | Restart whkd (setelah mengubah `whkdrc`) |
| `alt + i` | Toggle panel cheatsheet shortcut komorebi |
| `alt + space` | Quick launcher YASB |
| `alt + e` | Galeri wallpaper YASB |

---

## Workspace dan layout

Tiap workspace punya layout default sendiri, diatur di `komorebi/komorebi.json`:

| # | Nama | Layout |
|---|---|---|
| 1 | I | BSP |
| 2 | II | Vertical Stack |
| 3 | III | Horizontal Stack |
| 4 | IV | Ultrawide Vertical Stack |
| 5 | V | Rows |
| 6 | VI | Grid |
| 7 | VII | Right Main Vertical Stack |

Layout bisa diganti kapan saja lewat dropdown di bar (klik ikon layout) tanpa mengubah file config.

---

## Catatan penting

Hal-hal yang memakan waktu lama untuk ketahuan — baca kalau nanti ada yang aneh.

### `komorebic start` WAJIB pakai `--config`

Ini jebakan paling berbahaya di seluruh setup ini.

```powershell
komorebic start --whkd                                             # ❌ config TIDAK terbaca
komorebic start --config "$env:USERPROFILE\komorebi.json" --whkd   # ✅
```

Tanpa `--config`, komorebi jalan normal tanpa error apapun, tapi `komorebi.json` tidak dibaca sehingga `applications.json` tidak termuat — akibatnya **Windows Terminal (dan aplikasi multi-window lain) tidak dikelola sama sekali**.

Yang bikin susah terdeteksi: nama workspace tetap tampil benar (I–VII) karena komorebi memulihkan *state dump* dari sesi sebelumnya. State dump menyimpan nama dan layout workspace, **tapi tidak menyimpan aturan aplikasi**. Jadi jangan pakai nama workspace sebagai patokan.

Cara memastikan:

```powershell
Get-CimInstance Win32_Process -Filter "Name='komorebi.exe'" | Select-Object -ExpandProperty CommandLine
```

Harus ada `--config="..."` di situ. Kalau kosong, restart dengan flag yang benar.

Karena itu autostart lewat `komorebic enable-autostart --config ...` sangat disarankan — flag-nya tertanam permanen di shortcut, jadi tidak ada lagi kemungkinan lupa.

**Ada tiga jalur berbeda yang bisa menjalankan komorebi**, dan ketiganya harus memuat `--config`:

| Jalur | Di mana flag-nya diatur |
|---|---|
| Ketik manual di terminal | Perintahmu sendiri |
| Autostart saat login | `komorebi.lnk` di `shell:startup`, dibuat oleh `komorebic enable-autostart --config ...` |
| Menu tray YASB (klik kanan ikon YASB) | Blok `komorebi:` di `yasb/config.yaml` |

Jalur ketiga paling mudah terlewat. Blok `komorebi:` dibaca `core/tray.pyc` dan dijalankan lewat `subprocess.run(shell=True)`, jadi `%USERPROFILE%` ter-expand dengan benar:

```yaml
komorebi:
  start_command: 'komorebic start --whkd --config=%USERPROFILE%\komorebi.json'
  stop_command: 'komorebic stop --whkd'
  reload_command: 'komorebic reload-configuration'
```

Catatan: blok ini **hanya** memengaruhi menu tray. Tombol start/stop/reload di widget `komorebi_control` pada bar memakai jalurnya sendiri dan mengambil path dari `config_path` di widget itu — keduanya terpisah dan dua-duanya perlu benar.

`reload_command` sengaja memakai `reload-configuration`, bukan stop-lalu-start: lebih cepat karena tidak me-restart proses, dan mustahil kehilangan flag config.

### Aplikasi yang jalan sebagai Administrator tidak ter-tile

Gejalanya persis seperti kasus `--config` di atas — Windows Terminal / VS Code dibiarkan floating tanpa error apa pun — tapi penyebabnya beda: **window elevated hanya bisa dikelola oleh komorebi yang juga elevated**. Windows (UIPI) melarang proses non-elevated membaca informasi proses yang elevated, jadi komorebi tidak bisa tahu exe-nya dan menganggap window itu tidak eligible. `komorebic visible-windows` bahkan tidak menampilkannya.

Cara memastikan — kalau title window-nya diawali `Administrator:` atau diakhiri `[Administrator]`, itu window elevated. Cek komorebi-nya:

```powershell
# Terminal biasa (non-admin): kalau baris ini gagal "Access is denied", komorebi-nya elevated
(Get-Process komorebi).MainModule.FileName
```

Solusi: autostart lewat scheduled task elevated, lihat [Autostart → Varian elevated](#varian-elevated-wajib-kalau-ada-app-yang-jalan-as-administrator). Setelah komorebi elevated, window elevated baru langsung ter-tile.

### Window yang sudah ada sebelum komorebi start tidak otomatis di-manage

komorebi mengelola window saat menerima event *ObjectShow*. Window yang sudah terbuka sebelum komorebi jalan (dan tidak ada di state dump sesi sebelumnya) dibiarkan floating sampai ada event itu. Cukup **minimize lalu restore** window-nya, atau tutup-buka ulang. Ini normal, bukan masalah config.

### Aplikasi Electron dengan `WS_EX_LAYERED` (Claude Desktop) diabaikan komorebi

Window yang punya extended style `WS_EX_LAYERED` (biasanya Electron dengan transparansi/acrylic) di-filter komorebi sebelum sempat di-manage — tidak ada satu pun baris event-nya di log, jadi terlihat seperti "tidak terdeteksi". `applications.json` upstream sudah punya kategori `layered` untuk Discord, Zed, Office, tapi tidak mencakup app yang lebih baru. Config ini menambahkan **Claude Desktop** (`claude.exe`) dan **Hermes** (`Hermes.exe`) lewat `layered_applications` + `tray_and_multi_window_applications` di `komorebi.json`.

Cara cek app lain: `GetWindowLong(hwnd, GWL_EXSTYLE) & 0x80000` — kalau tidak nol, tambahkan exe-nya ke `layered_applications` di `komorebi.json` (bukan di `applications.json`, karena file itu ditimpa setiap `fetch-app-specific-configuration`).

Ini **akan terus terjadi untuk setiap app layered baru** sampai exe-nya didaftarkan — komorebi tidak punya opsi global "manage semua window layered", filternya by design (window layered biasanya overlay/transparansi yang memang tidak boleh di-tile). Pengecualian sementara tanpa mengubah config: fokuskan window-nya lalu `komorebic manage` (paksa manage untuk sesi ini saja).

Dua catatan saat menerapkannya:

- `komorebic reload-configuration` **tidak** cukup untuk `layered_applications` — pakai `komorebic replace-configuration "$env:USERPROFILE\komorebi.json"`.
- `replace-configuration` menginisialisasi ulang state, jadi semua window terkumpul lagi di workspace I. Setelah itu window layered yang sudah terbuka perlu minimize/restore supaya kena event Show.

### `KOMOREBI_CONFIG_HOME` tidak menggantikan `--config`

Env var itu hanya dipakai komorebic untuk *mencari* lokasi file config. `komorebic start` tetap menjalankan `komorebi.exe` tanpa argumen apapun meski variabel ini sudah diset.

### Windows 10 harus pakai `border_implementation: "Komorebi"`

```json
"border_implementation": "Komorebi"
```

Nilai `"Windows"` hanya didukung Windows 11 — di Windows 10 komorebi akan melempar error `BorderImplementation::Windows is only supported on Windows 11 and above` dan border tidak muncul. Nilai `"Native"` tidak valid sama sekali (bukan varian yang dikenal) dan membuat komorebi gagal start.

### Ejaan key di `komorebi.json` gampang salah

Schema komorebi memakai ejaan Inggris untuk warna:

```json
"border_colours"        // ✅ bukan border_colors
"border_implementation" // ✅ bukan border-implementation
"border_style"          // ✅
```

Key yang salah eja akan membuat komorebi **gagal start total**, bukan sekadar diabaikan. Validasi dengan `komorebic check` sebelum restart.

### Ikon layout di YASB pakai selector `.label`, bukan `.icon`

Widget `komorebi_active_layout` membuat `QLabel` biasa dengan `class="label"` — beda dari widget YASB lain yang memecah `<span>` menjadi elemen ber-class `icon`. Jadi font nerd harus diset di sini:

```css
.komorebi-active-layout .label {
    font-family: var(--icons-font-fallback);
}
```

Kalau diset di `.komorebi-active-layout .icon`, rule-nya tidak akan kena dan ikonnya jadi kotak kosong.

### Baris dropdown layout adalah `QFrame`

Di Qt, `:hover` tidak akan ter-*paint* pada `QFrame` kalau `background-color`-nya tidak dideklarasikan eksplisit lebih dulu:

```css
.komorebi-layout-menu .menu-item { background-color: transparent; }
.komorebi-layout-menu .menu-item:hover { background-color: var(--yasb-white-alpha-10); }
```

### Aplikasi dalam stack muncul dua kali di bar

Widget taskbar YASB tidak punya kesadaran soal stack komorebi — filternya hanya status *cloaked* dan daftar ignore statis. Jadi window yang sedang aktif di dalam stack tetap ikut tampil di taskbar, di samping ikonnya di widget `komorebi_stack`.

Ini keterbatasan YASB, bukan salah config. Pilihannya: terima saja (widget stack sudah ditaruh di grup kiri supaya tidak bersebelahan dengan taskbar), atau hapus `komorebi_stack` dari daftar widget dan pakai stackbar bawaan komorebi dengan mengubah `stackbar.mode` di `komorebi.json` dari `"Never"` jadi `"OnStack"`.

### Widget `afterburner` membaca shared memory MAHM

YASB tidak punya widget MSI Afterburner. Yang dipakai di sini adalah `yasb.custom.CustomWidget`: YASB menjalankan sebuah perintah tiap `run_interval`, mem-parse stdout-nya sebagai JSON, lalu memasukkannya ke label lewat `{data[key]}`.

Sumber datanya `yasb/scripts/afterburner-stats.ps1`. Afterburner mengekspos **seluruh** sensor monitoring-nya lewat shared memory bernama `MAHMSharedMemory` — formatnya didokumentasikan di `C:\Program Files (x86)\MSI Afterburner\SDK\Include\MAHMSharedMemory.h`. Script membukanya read-only dengan `MemoryMappedFile.OpenExisting` lalu membaca header v2.0 + array entry-nya. Tidak perlu elevasi: Afterburner sengaja mengizinkan proses lain membaca, jadi YASB yang non-elevated tetap bisa baca meski Afterburner-nya jalan elevated.

Lihat semua sensor yang tersedia di device-mu:

```powershell
# daftar sensor mentah dari Afterburner (source id, index, nama, nilai, unit)
& "$env:USERPROFILE\.config\yasb\scripts\afterburner-stats.ps1" -Raw

# JSON persis seperti yang dibaca YASB
& "$env:USERPROFILE\.config\yasb\scripts\afterburner-stats.ps1"
```

Empat hal yang bikin ini gampang salah:

**1. `run_cmd` tidak boleh dikutip dan tidak boleh berspasi.** YASB memecahnya dengan `run_cmd.split(' ')` jadi list argumen lalu memanggil `subprocess.Popen` tanpa shell. Tanda kutip yang kamu tulis ikut masuk ke argumen dan PowerShell menolak dengan `Illegal characters in path`. `install.ps1` otomatis memakai short path 8.3 kalau username-nya mengandung spasi.

**2. Signature header bukan `0x4D48414D`.** MSVC mengevaluasi literal multi-karakter `'MAHM'` dengan karakter pertama sebagai byte paling signifikan, jadi nilainya `0x4D41484D` — di memori byte-nya justru berurutan `MHAM`.

**3. `dwGpu` bukan selalu index GPU.** Untuk sensor per-core, Afterburner memakainya sebagai **index core**: `CPU1 temperature` punya `dwGpu = 0`, `CPU8 temperature` punya `dwGpu = 7`, dan baris agregat `CPU temperature` punya `dwGpu = 0xFFFFFFFF`. Kalau baris global tidak diprioritaskan, yang tampil di bar cuma core pertama. Tapi tidak semua sensor punya baris global — `RAM usage` hanya dilaporkan dengan `dwGpu = 0` — jadi script mencari baris global dulu, baru menerima index apa pun sebagai fallback.

**4. Sensor yang tidak dicentang tidak ada sama sekali.** Isi shared memory mengikuti centang di **Afterburner → Settings → Monitoring**. Sensor yang tidak aktif tidak masuk daftar dan keluar sebagai `--`. Beberapa sensor juga memang tidak dilaporkan kartu tertentu: RX 580 misalnya mengembalikan `dwMemAmount = 0` (total VRAM) dan tidak punya hotspot maupun Vcore.

Key JSON yang tersedia: `cpu_temp`, `cpu_usage`, `cpu_clock`, `cpu_clock_ghz`, `cpu_power`, `gpu_temp`, `gpu_hotspot`, `gpu_mem_temp`, `gpu_usage`, `gpu_core_clock`, `gpu_mem_clock`, `gpu_fan`, `gpu_fan_rpm`, `gpu_power`, `gpu_power_pct`, `gpu_voltage`, `gpu_vram_used`, `gpu_vram_gb`, `gpu_vram_total`, `gpu_vram_pct`, `ram_used_gb`, `fps`, `gpu_name`, `polled`, `status`.

Kalau Afterburner tidak jalan, script mencetak `{}` dan widget menyembunyikan diri (`hide_empty: true`). Set `hide_empty: false` kalau lebih suka widget-nya tetap kelihatan dengan `--`.

---

## Troubleshooting

### Windows Terminal tidak ikut di-tile

```powershell
Get-CimInstance Win32_Process -Filter "Name='komorebi.exe'" | Select-Object -ExpandProperty CommandLine
```

Tidak ada `--config`? Itu penyebabnya. Lihat [catatan di atas](#komorebic-start-wajib-pakai---config).

Sudah ada `--config` tapi tetap tidak terdeteksi? Cek `applications.json` ada dan berisi aturan terminal:

```powershell
Test-Path "$env:USERPROFILE\applications.json"
komorebic fetch-app-specific-configuration
komorebic reload-configuration
```

Sudah ada `--config`, `applications.json` ada, tapi tetap floating — dan title-nya ada `Administrator`? Terminalnya elevated, komorebi-nya tidak. Lihat [catatan soal Administrator](#aplikasi-yang-jalan-sebagai-administrator-tidak-ter-tile).

### Ikon di bar jadi kotak kosong

Font belum terpasang. Lihat [Prasyarat → Font](#font-wajib-jangan-dilewat). Setelah memasang font, jalankan `yasbc reload`.

### Bar tidak muncul atau ada widget yang hilang

```powershell
Get-Content "$env:USERPROFILE\.config\yasb\yasb.log" -Tail 40 | Select-String "ERROR"
```

`Failed to validate widget(s) due to invalid options - <nama>` berarti ada opsi yang tidak dikenal di widget itu. YASB memakai validasi ketat (`extra: forbid`), jadi satu key salah nama membuat seluruh widget gagal dimuat.

### Widget CPU/GPU (`afterburner`) tidak muncul

Widget ini memang menyembunyikan diri kalau datanya kosong, jadi cek dari sumbernya dulu — jalankan script-nya langsung:

```powershell
& "$env:USERPROFILE\.config\yasb\scripts\afterburner-stats.ps1"
```

| Yang keluar | Artinya |
|---|---|
| JSON berisi `"status":"ok"` | Script sehat. Masalahnya di `run_cmd` — cek path-nya benar dan **tanpa tanda kutip** (lihat [catatan](#widget-afterburner-membaca-shared-memory-mahm)) |
| `{}` + `MSI Afterburner tidak jalan` | Buka MSI Afterburner. Kalau ingin selalu jalan, daftarkan scheduled task autostart-nya |
| `{}` + `Shared memory belum siap` | Afterburner baru start dan belum polling sekali pun; tunggu sebentar |
| Nilainya `--` semua | Sensornya belum dicentang di Afterburner → Settings → Monitoring |

Kalau script sehat tapi bar tetap kosong, jalankan perintah yang sama persis seperti YASB memanggilnya (tanpa shell, argumen dipecah per spasi) untuk melihat error PowerShell yang biasanya tertelan:

```powershell
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.config\yasb\scripts\afterburner-stats.ps1"
```

### Workspace di bar tidak update

Pastikan YASB benar-benar tersambung ke komorebi:

```powershell
Get-Content "$env:USERPROFILE\.config\yasb\yasb.log" -Tail 60 | Select-String "Komorebi connected"
```

Kalau yang muncul hanya `Waiting for Komorebi to subscribe to named pipe`, berarti komorebi belum jalan. Start komorebi dulu, YASB akan menyambung sendiri.

### YASB di-quit dari tray tapi tidak mau jalan lagi

Cek log-nya:

```powershell
Get-Content "$env:USERPROFILE\.config\yasb\yasb.log" -Tail 5
```

Kalau isinya `Another instance of the YASB is already running`, proses lama belum benar-benar mati — *Exit* dari tray kadang cuma menghentikan listener-nya dan prosesnya menggantung. Bunuh paksa lalu jalankan lagi:

```powershell
Stop-Process -Name yasb -Force
yasbc start
```

Kasus ini muncul setelah komorebi di-stop/start beberapa kali berturut-turut: widget workspace dan stack jadi kosong karena listener kehilangan named pipe dan tidak menyambung ulang. Sebelum sampai quit, coba dulu `yasbc reload`.

### komorebi gagal start tanpa pesan jelas

Jalankan di foreground untuk melihat error aslinya:

```powershell
& "C:\Program Files\komorebi\bin\komorebi.exe" --config "$env:USERPROFILE\komorebi.json" --log-level info
```

### Ingin mulai dari kondisi bersih

Komorebi memulihkan state dump dari sesi sebelumnya secara otomatis. Untuk mengabaikannya:

```powershell
komorebic stop --whkd
komorebic start --config "$env:USERPROFILE\komorebi.json" --whkd --clean-state
```

---

## Update config

Setelah mengubah config di device manapun, salin balik ke repo lalu commit:

```powershell
Copy-Item "$env:USERPROFILE\komorebi.json"                  komorebi\komorebi.json -Force
Copy-Item "$env:USERPROFILE\.config\whkdrc"                 komorebi\whkdrc        -Force
Copy-Item "$env:USERPROFILE\.config\yasb\config.yaml"       yasb\config.yaml       -Force
Copy-Item "$env:USERPROFILE\.config\yasb\styles.css"        yasb\styles.css        -Force
```

> Ingat mengembalikan `config_path` dan `image_path` di `yasb/config.yaml` ke nilai yang netral sebelum commit, atau biarkan saja dan andalkan `install.ps1` untuk menimpanya di device tujuan.

---

## Kredit

- [komorebi](https://github.com/LGUG2Z/komorebi) — LGUG2Z
- [whkd](https://github.com/LGUG2Z/whkd) — LGUG2Z
- [YASB Reborn](https://github.com/amnweb/yasb) — amnweb
