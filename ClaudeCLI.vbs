' Claude CLI Launcher (Hydra Core)
' Auto-cleanup & Launch - PURE POWERSHELL VERSION
Option Explicit
On Error Resume Next

Dim objShell, objWMI, objFSO
Dim colProcesses, objProcess
Dim ports, port, killCount
Dim userProfile, strScriptPath

Set objShell = CreateObject("WScript.Shell")
Set objWMI = GetObject("winmgmts:\\.\root\cimv2")
Set objFSO = CreateObject("Scripting.FileSystemObject")

killCount = 0
userProfile = objShell.ExpandEnvironmentStrings("%USERPROFILE%")
strScriptPath = objFSO.GetParentFolderName(WScript.ScriptFullName)

' NOTE: Removed 9000 - that's Serena MCP server port, don't kill it!
ports = Array(8100, 5200, 9222)

' 1. CLEANUP (Serena is NOT killed - it's needed for MCP)

For Each port In ports
    CheckAndKillPort port
Next

CleanStaleLocks()

' 2. MCP HEALTH CHECK - sprawdź i uruchom ponownie zawieszone serwery
Dim healthCheckScript
healthCheckScript = strScriptPath & "\mcp-health-check.ps1"
If objFSO.FileExists(healthCheckScript) Then
    objShell.Run "powershell.exe -ExecutionPolicy Bypass -File """ & healthCheckScript & """", 1, True
End If

' 3. LAUNCH - uruchom Claude CLI
Dim tempPS1, psContent, objFile
tempPS1 = strScriptPath & "\_launcher.ps1"

psContent = "Set-Location '" & strScriptPath & "'" & vbCrLf & _
    "Write-Host 'Starting Claude CLI...' -ForegroundColor Cyan" & vbCrLf & _
    "Write-Host 'Working directory: ' -NoNewline; Write-Host (Get-Location) -ForegroundColor Gray" & vbCrLf & _
    "Write-Host ''" & vbCrLf & _
    "try { claude } catch { Write-Host ('ERROR: ' + $_) -ForegroundColor Red }" & vbCrLf & _
    "Write-Host ''" & vbCrLf & _
    "Write-Host 'Claude exited. Press any key to close...' -ForegroundColor Yellow" & vbCrLf & _
    "$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')"

Set objFile = objFSO.CreateTextFile(tempPS1, True)
objFile.Write psContent
objFile.Close

' Uruchom przez PowerShell
objShell.Run "powershell.exe -NoExit -ExecutionPolicy Bypass -Command ""Set-Location '" & strScriptPath & "'; $Host.UI.RawUI.WindowTitle = 'Claude CLI (Hydra)'; & '" & userProfile & "\AppData\Roaming\npm\claude.cmd'""", 1, False

' === FUNKCJE ===
Sub CheckAndKillPort(portNum)
    Dim objExec, strOutput, arrLines, strLine, arrParts, pid
    Set objExec = objShell.Exec("cmd /c netstat -ano | findstr :" & portNum)
    If Not objExec.StdOut.AtEndOfStream Then
        strOutput = objExec.StdOut.ReadAll()
    Else
        strOutput = ""
    End If
    
    If Len(Trim(strOutput)) > 0 Then
        arrLines = Split(strOutput, vbCrLf)
        For Each strLine In arrLines
            If InStr(strLine, "LISTENING") > 0 Then
                strLine = Trim(strLine)
                arrParts = Split(strLine, " ")
                pid = arrParts(UBound(arrParts))
                If IsNumeric(pid) And CInt(pid) > 0 Then
                    KillProcessByPID CInt(pid)
                End If
            End If
        Next
    End If
End Sub

Sub KillProcessByPID(pid)
    Dim colProcs, objProc
    On Error Resume Next
    Set colProcs = objWMI.ExecQuery("SELECT * FROM Win32_Process WHERE ProcessId = " & pid)
    For Each objProc In colProcs
        objProc.Terminate()
    Next
End Sub

Sub CleanStaleLocks()
    Dim lockPaths, lockPath, folder
    lockPaths = Array( _
        userProfile & "\.claude\locks", _
        userProfile & "\.claude\.locks", _
        userProfile & "\AppData\Local\Temp\claude-locks" _
    )
    For Each lockPath In lockPaths
        If objFSO.FolderExists(lockPath) Then
            Set folder = objFSO.GetFolder(lockPath)
            DeleteFilesInFolder folder
        End If
    Next
End Sub

Sub DeleteFilesInFolder(folder)
    Dim file, subfolder
    On Error Resume Next
    For Each file In folder.Files
        file.Delete True
    Next
    For Each subfolder In folder.SubFolders
        DeleteFilesInFolder subfolder
    Next
End Sub
