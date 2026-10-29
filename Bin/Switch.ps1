[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Disable', 'Enable')]
    [string]$Mode,
    [switch]$Worker
)

$ErrorActionPreference = 'Stop'
# PowerShell 7 callers can pass a module path that omits Windows PowerShell modules.
$env:PSModulePath = $PSHOME + '\Modules;' + $env:SystemRoot + '\System32\WindowsPowerShell\v1.0\Modules;' + $env:PSModulePath
$taskPath = '\Microsoft\Windows\Windows Defender\'
$taskNames = @('Windows Defender Cache Maintenance', 'Windows Defender Cleanup',
    'Windows Defender Scheduled Scan', 'Windows Defender Verification')
$preferences = @('DisableRealtimeMonitoring', 'DisableBehaviorMonitoring',
    'DisableIOAVProtection', 'DisableScriptScanning')
$services = [ordered]@{ WinDefend = 'Automatic'; MDCoreSvc = 'Automatic'; WdNisSvc = 'Manual'; SecurityHealthService = 'Manual'; wscsvc = 'Automatic' }
$trayPolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Systray'

function Set-TrayVisibility {
    param([bool]$Hidden)
    if ($Hidden) {
        $null = New-Item -Path $trayPolicy -Force
        $null = New-ItemProperty -Path $trayPolicy -Name HideSystray -Value 1 -PropertyType DWord -Force
        # Ask the shell to remove the icon before terminating its owner.
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class DefenderTray {
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
    public struct Data {
        public uint Size; public IntPtr Window; public uint Id, Flags, Callback;
        public IntPtr Icon;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=128)] public string Tip;
        public uint State, StateMask;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=256)] public string Info;
        public uint Timeout;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=64)] public string Title;
        public uint InfoFlags; public Guid Guid; public IntPtr Balloon;
    }
    [DllImport("shell32.dll", CharSet=CharSet.Unicode)]
    public static extern bool Shell_NotifyIcon(uint action, ref Data data);
    public static bool Remove() {
        var data=new Data(); data.Size=(uint)Marshal.SizeOf(data);
        data.Flags=0x20; data.Guid=new Guid("BA82E2DC-F405-47AD-B032-CF0FAA0E3933");
        return Shell_NotifyIcon(2,ref data);
    }
}
'@
        if (-not [DefenderTray]::Remove()) {
            Write-Host 'WARN: Shell did not confirm tray-icon removal in this session.' -ForegroundColor Yellow
        }
        Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' -Name SecurityHealth -ErrorAction SilentlyContinue
        Get-Process -Name SecurityHealthSystray -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction Stop
    } else {
        if (Test-Path $trayPolicy) { Remove-ItemProperty -Path $trayPolicy -Name HideSystray -ErrorAction SilentlyContinue }
        $null = New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' -Name SecurityHealth -PropertyType ExpandString -Value '%windir%\system32\SecurityHealthSystray.exe' -Force
        # The next interactive sign-in starts the tray in the correct user session.
    }
}

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-Change {
    param([string]$Label, [scriptblock]$Action)
    try { & $Action }
    catch { Write-Host ('WARN: {0}: {1}' -f $Label, $_.Exception.Message) -ForegroundColor Yellow }
}

function Get-StateIssues {
    param([bool]$Disabling)
    $status = Get-MpComputerStatus
    $settings = Get-MpPreference
    foreach ($name in $preferences) {
        if ($settings.$name -ne $Disabling) { 'Preference: ' + $name }
    }
    # Network inspection can be idle while enabled, so it is not an enable criterion.
    foreach ($name in @('RealTimeProtectionEnabled', 'BehaviorMonitorEnabled', 'IoavProtectionEnabled')) {
        if ($null -ne $status.$name -and $status.$name -ne (-not $Disabling)) {
            'Protection: ' + $name
        }
    }
    foreach ($name in $services.Keys) {
        $service = Get-Service -Name $name -ErrorAction SilentlyContinue
        if ($null -eq $service) { continue }
        if ($Disabling) {
            if ($service.Status -ne 'Stopped' -or $service.StartType -ne 'Disabled') {
                'Service still enabled: ' + $name
            }
        } else {
            if ([string]$service.StartType -ne $services[$name]) { 'Service startup: ' + $name }
            if ($services[$name] -eq 'Automatic' -and $service.Status -ne 'Running') {
                'Service not running: ' + $name
            }
        }
    }
    foreach ($name in $taskNames) {
        $task = Get-ScheduledTask -TaskPath $taskPath -TaskName $name -ErrorAction SilentlyContinue
        if ($null -eq $task) {
            if (-not $Disabling) { 'Scheduled task missing: ' + $name }
        } elseif ([bool]$task.Settings.Enabled -ne (-not $Disabling)) {
            'Scheduled task: ' + $name
        }
    }
    if ($Disabling) {
        if (Get-Process SecurityHealthSystray -ErrorAction SilentlyContinue) { 'Tray process still running' }
        if ((Get-ItemProperty -Path $trayPolicy -Name HideSystray -ErrorAction SilentlyContinue).HideSystray -ne 1) {
            'Tray hiding policy is not enabled'
        }
    }
    if (-not $Disabling) {
        if (-not $status.AMServiceEnabled -or -not $status.AntivirusEnabled) { 'Antivirus is not active' }
        # Older versions deleted these registrations. Do not invent version-specific repair data.
        $key = 'HKLM:\SOFTWARE\Microsoft\AMSI\Providers\{2781761E-28E0-4109-99FE-B9D127C57AFE}'
        if (-not (Test-Path -LiteralPath $key)) {
            'Defender AMSI registration missing; Windows component repair is required'
        }
    }
}

try {
    $powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    if (-not $Worker) {
        if (-not (Test-Administrator)) {
            $arguments = '-NoLogo -NoProfile -ExecutionPolicy Bypass -File "{0}" -Mode {1}' -f $PSCommandPath, $Mode
            $process = Start-Process -FilePath $powershell -ArgumentList $arguments -Verb RunAs -Wait -PassThru
            exit $process.ExitCode
        }
        $toolName = if ([Environment]::Is64BitOperatingSystem) { 'superUser64.exe' } else { 'superUser32.exe' }
        $tool = Join-Path $PSScriptRoot $toolName
        $expectedHash = if ([Environment]::Is64BitOperatingSystem) {
            'D077F8B5448EF64CB1DE5777B38996B09B99A4F0FDE002503E8839B72BDC394F'
        } else {
            'CDAAD2BA1C179C43A079D7F82C11B44FF6BD476CC209C8D20F3035134F6A2A8A'
        }
        if ((Get-FileHash -LiteralPath $tool -Algorithm SHA256).Hash -ne $expectedHash) {
            throw 'superUser checksum mismatch. Use the official 6.2 binary.'
        }
        $workerCommand = "& '" + $PSCommandPath.Replace("'", "''") + "' -Mode " + $Mode + ' -Worker'
        $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($workerCommand))
        & $tool /ws $powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -EncodedCommand $encodedCommand
        exit $LASTEXITCODE
    }

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $trustedInstaller = 'S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464'
    if ($identity.User.Value -ne 'S-1-5-18' -or $trustedInstaller -notin @($identity.Groups.Value)) {
        throw 'SYSTEM and TrustedInstaller privileges are required.'
    }
    if (-not (Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue)) {
        throw 'Microsoft Defender PowerShell commands are unavailable.'
    }
    $disabling = $Mode -eq 'Disable'
    if ((Get-MpComputerStatus).IsTamperProtected) {
        Write-Host 'WARN: Tamper protection is enabled. Windows may reject changes.' -ForegroundColor Yellow
    }

    # Restore services before asking Defender to enable protection.
    if (-not $disabling) {
        foreach ($name in $services.Keys) {
            if ($null -eq (Get-Service -Name $name -ErrorAction SilentlyContinue)) { continue }
            Invoke-Change $name {
                if ([string](Get-Service $name).StartType -ne $services[$name]) {
                    Set-Service -Name $name -StartupType $services[$name]
                }
                if ($services[$name] -eq 'Automatic') { Start-Service -Name $name }
            }
        }
    }
    foreach ($name in $preferences) {
        Invoke-Change $name {
            $parameters = @{ ErrorAction = 'Stop' }
            $parameters[$name] = $disabling
            Set-MpPreference @parameters
        }
    }
    foreach ($name in $taskNames) {
        $task = Get-ScheduledTask -TaskPath $taskPath -TaskName $name -ErrorAction SilentlyContinue
        if ($null -eq $task) { continue }
        Invoke-Change $name {
            if ($disabling) { $task | Disable-ScheduledTask | Out-Null }
            else { $task | Enable-ScheduledTask | Out-Null }
        }
    }
    Invoke-Change 'Windows Security tray' { Set-TrayVisibility -Hidden $disabling }
    if ($disabling) {
        foreach ($name in $services.Keys) {
            if ($null -eq (Get-Service -Name $name -ErrorAction SilentlyContinue)) { continue }
            Invoke-Change ($name + ' startup') { Set-Service -Name $name -StartupType Disabled }
            Invoke-Change ($name + ' stop') {
                # sc returns immediately; Stop-Service can wait indefinitely on a protected service.
                & "$env:SystemRoot\System32\sc.exe" stop $name | Out-Host
                if ($LASTEXITCODE -ne 0 -and (Get-Service $name).Status -ne 'Stopped') {
                    throw ('Service stop rejected: ' + $name)
                }
            }
        }
    }
    $issues = @(Get-StateIssues -Disabling $disabling)
    if ($issues.Count) {
        foreach ($issue in $issues) { Write-Host ('INCOMPLETE: ' + $issue) -ForegroundColor Yellow }
        Write-Host 'Changes are incomplete. A restart is not a guarantee of success.' -ForegroundColor Yellow
        exit 1
    }
    Write-Host ($Mode + ' verified successfully.') -ForegroundColor Green
    exit 0
} catch {
    Write-Host ('ERROR: ' + $_.Exception.Message) -ForegroundColor Red
    exit 2
}
