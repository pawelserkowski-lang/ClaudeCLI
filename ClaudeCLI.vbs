Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "powershell -ExecutionPolicy Bypass -NoExit -File ""_launcher.ps1""", 1, False
