<#
.SYNOPSIS
    Baca sensor hardware MSI Afterburner dan cetak JSON untuk widget custom YASB.

.DESCRIPTION
    MSI Afterburner mengekspos SEMUA sensor monitoring-nya lewat shared memory
    bernama "MAHMSharedMemory" (format didokumentasikan di
    "C:\Program Files (x86)\MSI Afterburner\SDK\Include\MAHMSharedMemory.h").
    Script ini membuka shared memory itu read-only, mengambil sensor CPU + GPU
    yang dipakai bar, lalu mencetak satu baris JSON berisi string yang sudah
    siap tampil (sudah dibulatkan, tidak terpengaruh locale).

    Kalau MSI Afterburner tidak jalan, script mencetak {} ke stdout dan
    alasannya ke stderr. Widget YASB dengan hide_empty: true akan otomatis
    menyembunyikan diri saat itu terjadi, jadi bar tidak menampilkan strip
    terus-terusan waktu Afterburner ditutup.

    CATATAN: yang tersedia di sini hanya sensor yang Afterburner AKTIFKAN di
    Settings > Monitoring. Sensor yang di-uncheck tidak masuk shared memory dan
    akan keluar sebagai "--". Pakai -Raw untuk melihat apa saja yang ada.

.PARAMETER Gpu
    Index GPU (0-based) yang dibaca kalau ada lebih dari satu GPU. Default 0.

.PARAMETER Raw
    Cetak tabel semua sensor yang dilaporkan Afterburner (source id, GPU, nama,
    nilai, unit) alih-alih JSON. Dipakai untuk mencari nama sensor tambahan.

.EXAMPLE
    .\afterburner-stats.ps1
    .\afterburner-stats.ps1 -Raw
    .\afterburner-stats.ps1 -Gpu 1
#>

[CmdletBinding()]
param(
    [int]$Gpu = 0,
    [switch]$Raw
)

$ErrorActionPreference = 'Stop'

# Layout struct dari MAHMSharedMemory.h. MAX_PATH = 260.
$MAX_PATH           = 260
# Header menyimpan dwSignature = 'MAHM' (multi-character literal MSVC), jadi
# karakter pertama jadi byte paling signifikan: 0x4D41484D. Di memori byte-nya
# justru berurutan "MHAM" - jangan tertukar dengan 0x4D48414D.
$HDR_SIGNATURE_OK   = 0x4D41484D    # 'MAHM'
$HDR_SIGNATURE_DEAD = 0xDEAD        # memory ditandai untuk dibebaskan
$ENTRY_OFF_DATA     = 5 * $MAX_PATH # 1300: setelah 5 buah char[MAX_PATH]
$ENTRY_SIZE_V2      = $ENTRY_OFF_DATA + 24
$GPU_INDEX_GLOBAL   = [uint32]::MaxValue  # 0xFFFFFFFF = sensor global (CPU, FPS)
$FLT_UNAVAILABLE    = 3.4e38        # FLT_MAX = data tidak tersedia
$MB_TO_GIB          = 1.0 / 1024.0   # Afterburner melapor MiB, bukan MB desimal

# Source id yang dipakai (MONITORING_SOURCE_ID_* di header SDK).
$SRC = @{
    GPU_TEMP      = 0x00
    PCB_TEMP      = 0x01
    MEM_TEMP      = 0x02
    FAN_PERCENT   = 0x10
    FAN_RPM       = 0x11
    CORE_CLOCK    = 0x20
    MEMORY_CLOCK  = 0x22
    GPU_USAGE     = 0x30
    VRAM_USED     = 0x31
    GPU_VOLTAGE   = 0x40
    FRAMERATE     = 0x50
    POWER_PERCENT = 0x60
    POWER_WATT    = 0x61
    CPU_TEMP      = 0x80
    CPU_USAGE     = 0x90
    RAM_USED      = 0x91
    CPU_CLOCK     = 0xA0
    CPU_POWER     = 0x100
}

function Write-Empty {
    param([string]$Reason)
    # stdout tetap JSON valid supaya widget YASB tidak kena JSONDecodeError.
    [Console]::Out.Write('{}')
    [Console]::Error.WriteLine($Reason)
}

function Read-FixedString {
    # char[MAX_PATH] dari Afterburner: ANSI, dipotong di NUL pertama.
    param([byte[]]$Bytes)
    $end = [Array]::IndexOf($Bytes, [byte]0)
    if ($end -lt 0) { $end = $Bytes.Length }
    if ($end -eq 0) { return '' }
    return [System.Text.Encoding]::Default.GetString($Bytes, 0, $end)
}

function Format-Sensor {
    # Bulatkan ke string pakai InvariantCulture supaya locale id-ID tidak
    # mengubah 1.5 jadi 1,5 di dalam JSON.
    param(
        $Value,
        [int]$Digits = 0,
        [double]$Scale = 1.0,
        [string]$Fallback = '--'
    )
    if ($null -eq $Value) { return $Fallback }
    return [string]::Format([cultureinfo]::InvariantCulture, "{0:F$Digits}", [double]$Value * $Scale)
}

# --- Buka shared memory ----------------------------------------------------
# Afterburner biasanya membuat map di namespace default; beberapa versi /
# konfigurasi session memakai prefix Global\. Coba dua-duanya.
$mmf = $null
foreach ($mapName in 'MAHMSharedMemory', 'Global\MAHMSharedMemory') {
    try {
        $mmf = [System.IO.MemoryMappedFiles.MemoryMappedFile]::OpenExisting(
            $mapName, [System.IO.MemoryMappedFiles.MemoryMappedFileRights]::Read)
        break
    } catch [System.IO.FileNotFoundException] {
        continue
    } catch {
        Write-Empty "Shared memory $mapName ada tapi tidak bisa dibuka: $($_.Exception.Message)"
        exit 0
    }
}

if ($null -eq $mmf) {
    Write-Empty 'MSI Afterburner tidak jalan (shared memory MAHMSharedMemory tidak ada).'
    exit 0
}

$stream = $null
$reader = $null
try {
    $stream = $mmf.CreateViewStream(0, 0, [System.IO.MemoryMappedFiles.MemoryMappedFileAccess]::Read)
    $reader = New-Object System.IO.BinaryReader($stream)

    # --- Header v2.0 -------------------------------------------------------
    $signature     = $reader.ReadUInt32()
    $version       = $reader.ReadUInt32()
    $headerSize    = $reader.ReadUInt32()
    $numEntries    = $reader.ReadUInt32()
    $entrySize     = $reader.ReadUInt32()
    $pollTime      = $reader.ReadUInt32()   # time_t 32-bit, detik UTC
    $numGpuEntries = 0
    $gpuEntrySize  = 0
    if ($headerSize -ge 32) {
        $numGpuEntries = $reader.ReadUInt32()
        $gpuEntrySize  = $reader.ReadUInt32()
    }

    if ($signature -eq $HDR_SIGNATURE_DEAD) {
        Write-Empty 'Afterburner sedang menutup shared memory (signature 0xDEAD).'
        exit 0
    }
    if ($signature -ne $HDR_SIGNATURE_OK) {
        Write-Empty ('Shared memory belum siap (signature 0x{0:X8}).' -f $signature)
        exit 0
    }
    if ($entrySize -lt $ENTRY_SIZE_V2) {
        Write-Empty ("Layout shared memory terlalu lama (entrySize $entrySize, butuh " +
                     "minimal $ENTRY_SIZE_V2 supaya field dwGpu/dwSrcId ada).")
        exit 0
    }

    # --- Baca semua entry sensor -------------------------------------------
    $rows = New-Object System.Collections.Generic.List[object]
    for ($i = 0; $i -lt $numEntries; $i++) {
        $base = [long]$headerSize + ([long]$i * $entrySize)

        $stream.Position = $base
        $name = Read-FixedString $reader.ReadBytes($MAX_PATH)
        $unit = Read-FixedString $reader.ReadBytes($MAX_PATH)

        $stream.Position = $base + $ENTRY_OFF_DATA
        $value  = [double]$reader.ReadSingle()
        $null   = $reader.ReadSingle()   # minLimit - tidak dipakai
        $null   = $reader.ReadSingle()   # maxLimit - tidak dipakai
        $null   = $reader.ReadUInt32()   # dwFlags  - tidak dipakai
        $gpuIdx = $reader.ReadUInt32()
        $srcId  = $reader.ReadUInt32()

        # FLT_MAX / NaN berarti sensor terdaftar tapi belum punya data.
        $available = -not ([double]::IsNaN($value) -or $value -ge $FLT_UNAVAILABLE)

        $rows.Add([pscustomobject]@{
            SrcId     = $srcId
            Gpu       = $gpuIdx
            Name      = $name
            Unit      = $unit
            Value     = $value
            Available = $available
        })
    }

    if ($Raw) {
        $rows | ForEach-Object {
            [pscustomobject]@{
                SrcId = '0x{0:X3}' -f $_.SrcId
                Gpu   = if ($_.Gpu -eq $GPU_INDEX_GLOBAL) { '-' } else { $_.Gpu }
                Name  = $_.Name
                Value = if ($_.Available) { Format-Sensor $_.Value 2 } else { 'n/a' }
                Unit  = $_.Unit
            }
        } | Format-Table -AutoSize
        $stamp = [DateTimeOffset]::FromUnixTimeSeconds($pollTime).ToLocalTime()
        Write-Host ('version 0x{0:X8}, {1} sensor, {2} GPU, polling terakhir {3:HH:mm:ss}' -f
            $version, $numEntries, $numGpuEntries, $stamp)
        exit 0
    }

    # --- Helper pencarian sensor -------------------------------------------
    function Get-BySrcId {
        param([int]$Id, [switch]$Aggregate)

        if (-not $Aggregate) {
            # Sensor GPU: dwGpu benar-benar index GPU.
            foreach ($row in $rows) {
                if ($row.SrcId -ne $Id -or $row.Gpu -ne $Gpu) { continue }
                if (-not $row.Available) { return $null }
                return $row.Value
            }
            return $null
        }

        # Sensor CPU/RAM/FPS. HATI-HATI: untuk sensor per-core Afterburner
        # memakai dwGpu sebagai INDEX CORE, bukan index GPU - misalnya
        # "CPU1 temperature" dwGpu=0 ... "CPU8 temperature" dwGpu=7, lalu
        # agregat "CPU temperature" dwGpu=0xFFFFFFFF. Jadi baris global harus
        # diutamakan, kalau tidak nilai yang tampil cuma core pertama.
        foreach ($row in $rows) {
            if ($row.SrcId -eq $Id -and $row.Gpu -eq $GPU_INDEX_GLOBAL) {
                if (-not $row.Available) { return $null }
                return $row.Value
            }
        }
        # Tidak semua sensor punya baris global: "RAM usage" misalnya hanya
        # dilaporkan dengan dwGpu = 0. Baru di sini index apa pun diterima.
        foreach ($row in $rows) {
            if ($row.SrcId -ne $Id) { continue }
            if (-not $row.Available) { return $null }
            return $row.Value
        }
        return $null
    }

    function Get-ByNameLike {
        # Untuk sensor dari plugin / vendor yang tidak punya source id sendiri
        # (hotspot AMD, dll). $Pattern adalah wildcard, case-insensitive.
        param([string]$Pattern)
        foreach ($row in $rows) {
            if ($row.Name -notlike $Pattern) { continue }
            if ($row.Gpu -ne $GPU_INDEX_GLOBAL -and $row.Gpu -ne $Gpu) { continue }
            if (-not $row.Available) { continue }
            return $row.Value
        }
        return $null
    }

    # --- GPU entry (nama kartu + total VRAM) -------------------------------
    $gpuName     = ''
    $vramTotalMb = $null
    if ($numGpuEntries -gt $Gpu -and $gpuEntrySize -ge (5 * $MAX_PATH + 4)) {
        $gpuBase = [long]$headerSize + ([long]$numEntries * $entrySize) + ([long]$Gpu * $gpuEntrySize)
        $stream.Position = $gpuBase + (2 * $MAX_PATH)              # lewati szGpuId + szFamily
        $gpuName = Read-FixedString $reader.ReadBytes($MAX_PATH)   # szDevice
        $stream.Position = $gpuBase + (5 * $MAX_PATH)
        $memAmountKb = $reader.ReadUInt32()                        # dwMemAmount dalam KB
        # Tidak semua kartu/driver melaporkannya (RX 580 mengembalikan 0).
        # Biarkan $null supaya keluar "--", bukan "0.0 GB" yang menyesatkan.
        if ($memAmountKb -gt 0) { $vramTotalMb = [double]$memAmountKb / 1024.0 }
    }

    # --- Ambil sensor ------------------------------------------------------
    $cpuTemp  = Get-BySrcId $SRC.CPU_TEMP  -Aggregate
    $cpuUsage = Get-BySrcId $SRC.CPU_USAGE -Aggregate
    $cpuClock = Get-BySrcId $SRC.CPU_CLOCK -Aggregate
    $cpuPower = Get-BySrcId $SRC.CPU_POWER -Aggregate
    $ramUsed  = Get-BySrcId $SRC.RAM_USED  -Aggregate
    $fps      = Get-BySrcId $SRC.FRAMERATE -Aggregate

    $gpuTemp    = Get-BySrcId $SRC.GPU_TEMP
    $gpuUsage   = Get-BySrcId $SRC.GPU_USAGE
    $coreClock  = Get-BySrcId $SRC.CORE_CLOCK
    $memClock   = Get-BySrcId $SRC.MEMORY_CLOCK
    $fanPercent = Get-BySrcId $SRC.FAN_PERCENT
    $fanRpm     = Get-BySrcId $SRC.FAN_RPM
    $powerWatt  = Get-BySrcId $SRC.POWER_WATT
    $powerPct   = Get-BySrcId $SRC.POWER_PERCENT
    $gpuVolt    = Get-BySrcId $SRC.GPU_VOLTAGE
    $vramUsed   = Get-BySrcId $SRC.VRAM_USED
    $memTemp    = Get-BySrcId $SRC.MEM_TEMP

    # Hotspot/junction: AMD melaporkannya lewat nama, bukan source id khusus.
    $hotspot = Get-ByNameLike '*hot*'
    if ($null -eq $hotspot) { $hotspot = Get-ByNameLike '*junction*' }
    if ($null -eq $hotspot) { $hotspot = Get-BySrcId $SRC.PCB_TEMP }

    $vramPct = $null
    if ($null -ne $vramUsed -and $null -ne $vramTotalMb -and $vramTotalMb -gt 0) {
        $vramPct = ($vramUsed / $vramTotalMb) * 100.0
    }

    $out = [ordered]@{
        status         = 'ok'
        gpu_name       = $gpuName
        polled         = [DateTimeOffset]::FromUnixTimeSeconds($pollTime).ToLocalTime().ToString('HH:mm:ss')

        cpu_temp       = Format-Sensor $cpuTemp
        cpu_usage      = Format-Sensor $cpuUsage
        cpu_clock      = Format-Sensor $cpuClock
        cpu_clock_ghz  = Format-Sensor $cpuClock 2 0.001
        cpu_power      = Format-Sensor $cpuPower

        gpu_temp       = Format-Sensor $gpuTemp
        gpu_hotspot    = Format-Sensor $hotspot
        gpu_mem_temp   = Format-Sensor $memTemp
        gpu_usage      = Format-Sensor $gpuUsage
        gpu_core_clock = Format-Sensor $coreClock
        gpu_mem_clock  = Format-Sensor $memClock
        gpu_fan        = Format-Sensor $fanPercent
        gpu_fan_rpm    = Format-Sensor $fanRpm
        gpu_power      = Format-Sensor $powerWatt
        gpu_power_pct  = Format-Sensor $powerPct
        gpu_voltage    = Format-Sensor $gpuVolt 0 1000     # Afterburner melapor dalam Volt
        gpu_vram_used  = Format-Sensor $vramUsed
        gpu_vram_gb    = Format-Sensor $vramUsed 1 $MB_TO_GIB
        gpu_vram_total = Format-Sensor $vramTotalMb 1 $MB_TO_GIB
        gpu_vram_pct   = Format-Sensor $vramPct

        ram_used_gb    = Format-Sensor $ramUsed 1 $MB_TO_GIB
        fps            = Format-Sensor $fps
    }

    [Console]::Out.Write(($out | ConvertTo-Json -Compress))
} finally {
    if ($reader) { $reader.Dispose() }
    if ($stream) { $stream.Dispose() }
    if ($mmf)    { $mmf.Dispose() }
}
