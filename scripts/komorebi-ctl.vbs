' komorebi-ctl.vbs start|stop|restart
'
' Dipakai oleh YASB (widget komorebi_ctl di bar dan menu tray) untuk
' mengendalikan komorebi tanpa jendela console yang berkedip.
'
' Kalau scheduled task "komorebi Elevated Autostart" ada (dibuat oleh
' scripts\install-elevated-autostart.ps1), start dilakukan lewat task itu
' supaya komorebi jalan elevated. Kalau tidak ada, jatuh ke
' `komorebic start --config %USERPROFILE%\komorebi.json --whkd` biasa.
Option Explicit
Dim sh, action, home, taskName, hasTask

If WScript.Arguments.Count = 0 Then WScript.Quit 1
Set sh = CreateObject("WScript.Shell")
action   = LCase(WScript.Arguments(0))
home     = sh.ExpandEnvironmentStrings("%USERPROFILE%")
taskName = "komorebi Elevated Autostart"
hasTask  = (sh.Run("schtasks /query /tn """ & taskName & """", 0, True) = 0)

If action = "stop" Or action = "restart" Then
    sh.Run "komorebic stop", 0, True
End If

If action = "start" Or action = "restart" Then
    If hasTask Then
        sh.Run "schtasks /run /tn """ & taskName & """", 0, True
    Else
        sh.Run "komorebic start --config """ & home & "\komorebi.json"" --whkd", 0, False
    End If
End If
