$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:USERPROFILE\Desktop\ClaudeHYDRA.lnk")
$Shortcut.TargetPath = "cmd.exe"
$Shortcut.Arguments = '/c cd /d "C:\Users\BIURODOM\Desktop\ClaudeHYDRA\hydra-launcher" && pnpm tauri dev'
$Shortcut.WorkingDirectory = "C:\Users\BIURODOM\Desktop\ClaudeHYDRA\hydra-launcher"
$Shortcut.IconLocation = "C:\Users\BIURODOM\Desktop\ClaudeHYDRA\hydra-launcher\public\icon.ico,0"
$Shortcut.Description = "HYDRA 10.4 Launcher Dev"
$Shortcut.Save()

Write-Host "Shortcut created: ClaudeHYDRA.lnk" -ForegroundColor Green
