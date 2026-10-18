# Stream Deck launcher: restart only the instance recorded in the temp folder.
$ErrorActionPreference = 'Stop'
$godot = $null
$consoleDetached = $false
$statePath = Join-Path ([System.IO.Path]::GetTempPath()) 'packbound-streamdeck.pid'
$mutex = New-Object System.Threading.Mutex($false, 'Local\PackboundStreamDeckLauncher')
$ownsMutex = $false

try {
    $ownsMutex = $mutex.WaitOne(0)
    if (-not $ownsMutex) { exit 0 }
    if ([string]::IsNullOrWhiteSpace($env:APPS_ROOT)) {
        throw 'APPS_ROOT environment variable is not set.'
    }
    $godot = Join-Path $env:APPS_ROOT 'Installs\Godot\Godot_v4.7.2-stable_win64.exe'
    if (-not (Test-Path -LiteralPath $godot -PathType Leaf)) {
        throw "Godot executable not found: $godot"
    }
    if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'project.godot'))) {
        throw 'Place this script beside project.godot.'
    }

    # Plain text: PID and executable process name.
    # Intentionally accepts the small risk of PID reuse by the same executable.
    if (Test-Path -LiteralPath $statePath) {
        $state = @(Get-Content -LiteralPath $statePath)
        $trackedId = 0
        if ($state.Count -ge 2 -and
            [int]::TryParse($state[0], [ref]$trackedId) -and
            $trackedId -gt 0 -and
            $state[1] -eq [System.IO.Path]::GetFileNameWithoutExtension($godot)) {
            $previous = Get-Process -Id $trackedId -ErrorAction SilentlyContinue
            if ($null -ne $previous) {
                try {
                    $matches = $previous.ProcessName -eq $state[1]
                    if ($matches) {
                        if ($previous.CloseMainWindow()) {
                            if (-not $previous.WaitForExit(5000)) { $previous.Kill() }
                        } else {
                            $previous.Kill()
                        }
                        $previous.WaitForExit()
                    }
                } finally {
                    $previous.Dispose()
                }
            }
        }
        Remove-Item -LiteralPath $statePath
    }

    $import = Start-Process -FilePath $godot -ArgumentList ('--headless --path "{0}" --import' -f $PSScriptRoot) -WorkingDirectory $PSScriptRoot -NoNewWindow -Wait -PassThru
    try {
        if ($import.ExitCode -ne 0) { throw "Godot import failed (exit code $($import.ExitCode))." }
    } finally {
        $import.Dispose()
    }

    # Godot attaches to its parent's console, even when launched separately.
    # Detach before spawning it so the game cannot keep the terminal alive.
    Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;
public static class PackboundLauncherConsole {
    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool FreeConsole();
}
'@
    if (-not [PackboundLauncherConsole]::FreeConsole()) {
        throw 'Could not detach the launcher console.'
    }
    $consoleDetached = $true

    $game = Start-Process -FilePath $godot -ArgumentList ('--path "{0}" --windowed --screen 1 --resolution 1600x900' -f $PSScriptRoot) -WorkingDirectory $PSScriptRoot -PassThru
    try {
        @([string]$game.Id, [System.IO.Path]::GetFileNameWithoutExtension($godot)) |
            Set-Content -LiteralPath $statePath -Encoding UTF8
    } finally {
        $game.Dispose()
    }
} catch {
    if ($consoleDetached) {
        Add-Type -AssemblyName System.Windows.Forms
        $null = [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Packbound launcher')
    } else {
        Write-Host "Packbound launcher: $($_.Exception.Message)" -ForegroundColor Red
        $null = Read-Host 'Press Enter to close'
    }
    exit 1
} finally {
    if ($ownsMutex) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}
