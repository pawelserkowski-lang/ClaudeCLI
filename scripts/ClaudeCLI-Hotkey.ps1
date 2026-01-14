#Requires -Version 5.1
<#
.SYNOPSIS
    Global Win+C Hotkey for ClaudeCLI
.DESCRIPTION
    Registers Win+C as global hotkey to launch ClaudeCLI.
    Runs in system tray with minimal resource usage.
.NOTES
    Author: HYDRA System
    Path: C:\Users\BIURODOM\Desktop\ClaudeCLI\ClaudeCLI-Hotkey.ps1
#>

param(
    [switch]$Install,
    [switch]$Uninstall,
    [switch]$Silent
)

$ProjectRoot = "C:\Users\BIURODOM\Desktop\ClaudeCLI"
$HotkeyName = "ClaudeCLI-WinC"

# Win32 API for hotkey registration
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class GlobalHotkey : IDisposable {
    [DllImport("user32.dll")]
    private static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

    [DllImport("user32.dll")]
    private static extern bool UnregisterHotKey(IntPtr hWnd, int id);

    private const uint MOD_WIN = 0x0008;
    private const uint VK_C = 0x43;
    private const int HOTKEY_ID = 9000;

    private Form _form;
    private bool _registered = false;

    public event EventHandler HotkeyPressed;

    public GlobalHotkey() {
        _form = new Form();
        _form.ShowInTaskbar = false;
        _form.WindowState = FormWindowState.Minimized;
        _form.Visible = false;
        _form.FormBorderStyle = FormBorderStyle.None;
        _form.Load += (s, e) => { _form.Visible = false; };
    }

    public bool Register() {
        _form.Show();
        _form.Visible = false;
        _registered = RegisterHotKey(_form.Handle, HOTKEY_ID, MOD_WIN, VK_C);
        return _registered;
    }

    public void ProcessMessages() {
        Application.DoEvents();
    }

    public void Dispose() {
        if (_registered) {
            UnregisterHotKey(_form.Handle, HOTKEY_ID);
        }
        _form?.Dispose();
    }
}
"@ -ReferencedAssemblies System.Windows.Forms

# Alternative: Use PowerShell job with keyboard hook
Add-Type -TypeDefinition @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class KeyboardHook {
    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100;
    private const int VK_C = 0x43;
    private const int VK_LWIN = 0x5B;
    private const int VK_RWIN = 0x5C;

    [DllImport("user32.dll")]
    private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc callback, IntPtr hInstance, uint threadId);

    [DllImport("user32.dll")]
    private static extern bool UnhookWindowsHookEx(IntPtr hhk);

    [DllImport("user32.dll")]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

    [DllImport("kernel32.dll")]
    private static extern IntPtr GetModuleHandle(string lpModuleName);

    [DllImport("user32.dll")]
    private static extern short GetAsyncKeyState(int vKey);

    private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);

    private static LowLevelKeyboardProc _proc;
    private static IntPtr _hookID = IntPtr.Zero;
    public static bool WinCPressed = false;

    public static void Start() {
        _proc = HookCallback;
        using (Process curProcess = Process.GetCurrentProcess())
        using (ProcessModule curModule = curProcess.MainModule) {
            _hookID = SetWindowsHookEx(WH_KEYBOARD_LL, _proc, GetModuleHandle(curModule.ModuleName), 0);
        }
    }

    public static void Stop() {
        UnhookWindowsHookEx(_hookID);
    }

    private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
        if (nCode >= 0 && wParam == (IntPtr)WM_KEYDOWN) {
            int vkCode = Marshal.ReadInt32(lParam);
            if (vkCode == VK_C) {
                bool winPressed = (GetAsyncKeyState(VK_LWIN) & 0x8000) != 0 ||
                                  (GetAsyncKeyState(VK_RWIN) & 0x8000) != 0;
                if (winPressed) {
                    WinCPressed = true;
                }
            }
        }
        return CallNextHookEx(_hookID, nCode, wParam, lParam);
    }
}
"@ -ReferencedAssemblies System.Windows.Forms

function Install-Hotkey {
    $taskName = $HotkeyName
    $scriptPath = Join-Path $ProjectRoot "ClaudeCLI-Hotkey.ps1"

    # Create scheduled task to run at logon
    $action = New-ScheduledTaskAction -Execute "powershell.exe" `
        -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`" -Silent"

    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME

    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -ExecutionTimeLimit (New-TimeSpan -Hours 0) `
        -RestartCount 3 `
        -RestartInterval (New-TimeSpan -Minutes 1)

    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

    # Remove existing task if present
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

    # Register new task
    Register-ScheduledTask -TaskName $taskName `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Principal $principal `
        -Description "Global Win+C hotkey for ClaudeCLI" | Out-Null

    Write-Host "[OK] Hotkey Win+C installed" -ForegroundColor Green
    Write-Host "     Starts automatically at logon" -ForegroundColor Gray
    Write-Host "     To start now, run: Start-ScheduledTask -TaskName '$taskName'" -ForegroundColor Gray

    # Start immediately
    Start-ScheduledTask -TaskName $taskName
    Write-Host "[OK] Hotkey service started" -ForegroundColor Green
}

function Uninstall-Hotkey {
    $taskName = $HotkeyName

    # Stop running instances
    Get-Process -Name "powershell" -ErrorAction SilentlyContinue | Where-Object {
        $_.CommandLine -like "*ClaudeCLI-Hotkey*"
    } | Stop-Process -Force -ErrorAction SilentlyContinue

    # Remove scheduled task
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

    Write-Host "[OK] Hotkey Win+C uninstalled" -ForegroundColor Green
}

function Start-HotkeyListener {
    if (-not $Silent) {
        Write-Host "ClaudeCLI Hotkey Listener" -ForegroundColor Cyan
        Write-Host "Press Win+C to launch ClaudeCLI" -ForegroundColor Gray
        Write-Host "Press Ctrl+C to exit" -ForegroundColor Gray
        Write-Host ""
    }

    # Start keyboard hook
    [KeyboardHook]::Start()

    try {
        while ($true) {
            Start-Sleep -Milliseconds 100

            if ([KeyboardHook]::WinCPressed) {
                [KeyboardHook]::WinCPressed = $false

                # Launch ClaudeCLI
                $vbsPath = Join-Path $ProjectRoot "ClaudeCLI.vbs"
                if (Test-Path $vbsPath) {
                    Start-Process "wscript.exe" -ArgumentList "`"$vbsPath`"" -WorkingDirectory $ProjectRoot
                    if (-not $Silent) {
                        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Launched ClaudeCLI" -ForegroundColor Green
                    }
                }
            }

            [System.Windows.Forms.Application]::DoEvents()
        }
    } finally {
        [KeyboardHook]::Stop()
    }
}

# Main execution
Add-Type -AssemblyName System.Windows.Forms

if ($Install) {
    Install-Hotkey
} elseif ($Uninstall) {
    Uninstall-Hotkey
} else {
    Start-HotkeyListener
}
