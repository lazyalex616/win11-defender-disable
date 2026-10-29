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
$defendnotPath = Join-Path $env:ProgramFiles 'defendnot'
$defendnotHashes = @{
    'defendnot-loader.exe' = 'F57A4DD3BD3CE82EAF6D7143E837B3FA59A0ACCDAC76FD3DC053433EFDD50E5E'
    'defendnot.dll' = 'B0870E105C7AD37FB0BDCB9305279B2943810D55300E8721EB64BDAA588CC84E'
}

function Invoke-Defendnot {
    param([bool]$Disabling)
    Set-Service wscsvc -StartupType Automatic
    Start-Service wscsvc
    if ($Disabling) {
        $null = [IO.Directory]::CreateDirectory($defendnotPath)
        foreach ($name in $defendnotHashes.Keys) {
            $source = Join-Path $PSScriptRoot ('defendnot\' + $name)
            if ((Get-FileHash $source).Hash -ne $defendnotHashes[$name]) { throw ('Bundled checksum: ' + $name) }
            $target = Join-Path $defendnotPath $name
            if ((Test-Path $target) -and (Get-FileHash $target).Hash -ne $defendnotHashes[$name]) {
                throw ('Different defendnot installation found: ' + $target)
            }
            if (-not (Test-Path $target)) {
                Copy-Item -LiteralPath $source -Destination $target -Force
            }
        }
    } elseif (-not (Test-Path (Join-Path $defendnotPath 'defendnot-loader.exe'))) {
        return
    }
    foreach ($name in $defendnotHashes.Keys) {
        if ((Get-FileHash (Join-Path $defendnotPath $name)).Hash -ne $defendnotHashes[$name]) {
            throw ('Installed defendnot checksum: ' + $name)
        }
    }
    $arguments = if ($Disabling) { '--silent' } else { '--silent --disable' }
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = Join-Path $defendnotPath 'defendnot-loader.exe'
    $start.Arguments = $arguments
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $process = [Diagnostics.Process]::Start($start)
    $output = $process.StandardOutput.ReadToEndAsync()
    $errorOutput = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(60000)) {
        $process.Kill()
        throw 'defendnot timed out; inspect actual state before retrying.'
    }
    if ($process.ExitCode -ne 0 -or $output.Result -notmatch 'success: true') {
        throw ('defendnot failed: ' + $output.Result + $errorOutput.Result)
    }
}

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
    $settings = if (-not $Disabling) { Get-MpPreference -ErrorAction Stop } else { $null }
    foreach ($name in $preferences) {
        if ($Disabling) { continue }
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
            if ($name -in @('wscsvc', 'SecurityHealthService')) { continue }
            if ($service.Status -ne 'Stopped') {
                'Service still running: ' + $name
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
            # Windows removes scan tasks while another antivirus is registered.
            # Missing tasks do not by themselves prove protection failed to start.
        } elseif ([bool]$task.Settings.Enabled -ne (-not $Disabling)) {
            'Scheduled task: ' + $name
        }
    }
    if ($Disabling) {
        if ($status.AMServiceEnabled -or $status.AntivirusEnabled -or $status.AMRunningMode -ne 'Not running') {
            'Defender engine is not inactive'
        }
        $products = @(Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct)
        if (-not ($products | Where-Object { $_.displayName -eq 'dnot.sh' })) { 'defendnot registration missing' }
        $autorun = Get-ScheduledTask -TaskName defendnot -ErrorAction SilentlyContinue
        if ($null -eq $autorun -or -not $autorun.Settings.Enabled) { 'defendnot autorun missing or disabled' }
        if ((Get-Service wscsvc).Status -ne 'Running') { 'Required security-center service is not running' }
        if (Get-Process SecurityHealthSystray -ErrorAction SilentlyContinue) { 'Tray process still running' }
        if ((Get-ItemProperty -Path $trayPolicy -Name HideSystray -ErrorAction SilentlyContinue).HideSystray -ne 1) {
            'Tray hiding policy is not enabled'
        }
    }
    if (-not $Disabling) {
        if (-not $status.AMServiceEnabled -or -not $status.AntivirusEnabled) { 'Antivirus is not active' }
        $products = @(Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct)
        if ($products | Where-Object { $_.displayName -eq 'dnot.sh' }) { 'defendnot registration still present' }
        $autorun = Get-ScheduledTask -TaskName defendnot -ErrorAction SilentlyContinue
        if ($null -ne $autorun -and $autorun.Settings.Enabled) { 'defendnot autorun still enabled' }
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
    if (-not [Environment]::Is64BitOperatingSystem -or $env:PROCESSOR_ARCHITECTURE -eq 'ARM64') {
        throw 'The integrated defendnot package currently supports x64 Windows only.'
    }
    if ($disabling -and (Get-MpComputerStatus).IsTamperProtected) {
        throw 'Turn off tamper protection in Windows Security before disabling Defender.'
    }
    if ((Get-MpComputerStatus).IsTamperProtected) {
        Write-Host 'WARN: Tamper protection is enabled. Windows may reject changes.' -ForegroundColor Yellow
    }

    # WSC must remain available for both registration and unregistration.
    if (-not $disabling) { Invoke-Defendnot -Disabling $false }
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
        if ($disabling -and -not (Get-MpComputerStatus).AMServiceEnabled) { break }
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
        Invoke-Defendnot -Disabling $true
    }
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    do {
        $status = Get-MpComputerStatus
        $runningEngines = @(Get-Service WinDefend, MDCoreSvc, WdNisSvc -ErrorAction SilentlyContinue |
            Where-Object { $_.Status -ne 'Stopped' })
        if ($disabling -and -not $status.AMServiceEnabled -and -not $status.AntivirusEnabled -and $runningEngines.Count -eq 0) { break }
        if (-not $disabling -and $status.AntivirusEnabled -and $status.RealTimeProtectionEnabled) { break }
        Start-Sleep -Seconds 1
    } while ([DateTime]::UtcNow -lt $deadline)
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
