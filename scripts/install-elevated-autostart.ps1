<#
  Daftarkan komorebi + whkd sebagai scheduled task "Run with highest privileges"
  yang jalan saat logon, menggantikan shell:startup\komorebi.lnk.

  Kenapa: Windows Terminal dan VS Code di PC ini dijalankan sebagai Administrator.
  komorebi yang non-elevated tidak bisa membaca exe / mengelola window elevated
  (UIPI), jadi Terminal & VS Code terlihat "tidak terdeteksi". Pola yang sama
  dulu dipakai untuk FancyWM.

  Jalankan dari PowerShell yang elevated (Run as administrator):
    powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.config\komorebi-extra\install-elevated-autostart.ps1"
#>
$ErrorActionPreference = 'Stop'
$TaskName = 'komorebi Elevated Autostart'
$User     = "$env:USERDOMAIN\$env:USERNAME"

$action   = New-ScheduledTaskAction -Execute 'C:\Program Files\komorebi\bin\komorebic-no-console.exe' `
              -Argument "start --config `"$env:USERPROFILE\komorebi.json`" --whkd"
$trigger  = New-ScheduledTaskTrigger -AtLogOn -User $User
$trigger.Delay = 'PT5S'
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
              -ExecutionTimeLimit ([TimeSpan]::Zero) -StartWhenAvailable -MultipleInstances IgnoreNew
$principal = New-ScheduledTaskPrincipal -UserId $User -LogonType Interactive -RunLevel Highest

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings `
    -Principal $principal -Force `
    -Description 'Start komorebi + whkd elevated at logon so it can manage elevated Windows Terminal / VS Code windows.' | Out-Null
Write-Host "OK  task '$TaskName' terdaftar (RunLevel Highest, AtLogOn +5s)" -ForegroundColor Green

# Shortcut startup yang lama akan menjalankan instance kedua yang non-elevated -> hapus
komorebic disable-autostart | Out-Null
Write-Host 'OK  shell:startup\komorebi.lnk dihapus' -ForegroundColor Green

# Task FancyWM lama: exe-nya sudah tidak terpasang tapi task masih fire tiap logon
if (Get-ScheduledTask 'FancyWM Elevated Autostart' -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName 'FancyWM Elevated Autostart' -Confirm:$false
    Write-Host 'OK  task FancyWM Elevated Autostart (mati) dihapus' -ForegroundColor Green
}

Write-Host ''
Write-Host 'Tes tanpa reboot: komorebic stop --whkd ; schtasks /run /tn "komorebi Elevated Autostart"' -ForegroundColor Gray
