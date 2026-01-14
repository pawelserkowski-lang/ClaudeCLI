# System Utilities (Windows)

Given that the ClaudeCLI project operates on Windows, the following system utility commands (primarily PowerShell cmdlets) are relevant for file system navigation, manipulation, and general system interaction. These are analogous to common Unix/Linux commands.

- **List Directory Contents (`ls` equivalent):**
  ```powershell
  Get-ChildItem -Path .\
  ```
  *Recursively list directory contents:* 
  ```powershell
  Get-ChildItem -Path .\ -Recurse
  ```

- **Change Directory (`cd` equivalent):**
  ```powershell
  Set-Location -Path .\ai-handler\
  ```

- **Search File Content (`grep` equivalent):**
  ```powershell
  Select-String -Path .\README.md -Pattern "ClaudeCLI"
  ```

- **Find Files (`find` equivalent):**
  ```powershell
  Get-ChildItem -Path .\ -Filter "*.ps1" -Recurse
  ```

- **Remove Item (`rm` equivalent):**
  ```powershell
  Remove-Item -Path .\tempfile.txt
  # Force removal
  Remove-Item -Path .\tempfile.txt -Force
  # Recursively remove a directory
  Remove-Item -Path .\tempdir -Recurse -Force
  ```

- **Copy Item (`cp` equivalent):**
  ```powershell
  Copy-Item -Path .\source.txt -Destination .\destination.txt
  ```

- **Move/Rename Item (`mv` equivalent):**
  ```powershell
  Move-Item -Path .\oldname.txt -Destination .\newname.txt
  ```

- **Get Command Information:**
  ```powershell
  Get-Command -Name Get-ChildItem
  ```

- **View File Content (`cat`/`type` equivalent):**
  ```powershell
  Get-Content -Path .\README.md
  ```

- **Environment Variables:**
  ```powershell
  Get-ChildItem env:
  ```

- **Process Management:**
  ```powershell
  Get-Process
  Stop-Process -Id <PID>
  ```