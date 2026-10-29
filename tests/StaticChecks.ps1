$ErrorActionPreference = 'Stop'
$env:PSModulePath = $PSHOME + '\Modules;' + $env:SystemRoot + '\System32\WindowsPowerShell\v1.0\Modules;' + $env:PSModulePath
$root = Split-Path $PSScriptRoot
$core = Join-Path $root 'Bin\Switch.ps1'
$tokens = $null
$errors = $null
$null = [Management.Automation.Language.Parser]::ParseFile($core, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw ($errors | Out-String) }
$text = [IO.File]::ReadAllText($core)
foreach ($forbidden in @('reg.exe', 'Restart-Computer', 'Set-NetFirewallProfile')) {
    if ($text.Contains($forbidden)) { throw ('Unexpected operation: ' + $forbidden) }
}
if ($text -notmatch 'Get-StateIssues -Disabling') { throw 'Final state verification is missing' }
if ($text -notmatch 'exit \$LASTEXITCODE') { throw 'Child exit code is not propagated' }
$hashes = @{
    'superUser32.exe' = 'CDAAD2BA1C179C43A079D7F82C11B44FF6BD476CC209C8D20F3035134F6A2A8A'
    'superUser64.exe' = 'D077F8B5448EF64CB1DE5777B38996B09B99A4F0FDE002503E8839B72BDC394F'
    'defendnot\defendnot-loader.exe' = 'F57A4DD3BD3CE82EAF6D7143E837B3FA59A0ACCDAC76FD3DC053433EFDD50E5E'
    'defendnot\defendnot.dll' = 'B0870E105C7AD37FB0BDCB9305279B2943810D55300E8721EB64BDAA588CC84E'
}
foreach ($name in $hashes.Keys) {
    if ((Get-FileHash (Join-Path $root ('Bin\' + $name))).Hash -ne $hashes[$name]) { throw ('Checksum: ' + $name) }
}
Get-ChildItem -LiteralPath $root -Filter '*.CMD' -Recurse | ForEach-Object {
    $content = [IO.File]::ReadAllText($_.FullName)
    if ($content -notmatch 'Switch.ps1') { throw ('Missing core call: ' + $_.Name) }
    if ($content -notmatch 'exit /b') { throw ('Missing exit code: ' + $_.Name) }
}
# Extract only the verifier so no service-changing code can run in these checks.
$ast = [Management.Automation.Language.Parser]::ParseFile($core, [ref]$tokens, [ref]$errors)
$function = $ast.Find({ param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Get-StateIssues'
}, $true)
. ([scriptblock]::Create($function.Extent.Text))
$taskPath = '\Microsoft\Windows\Windows Defender\'
$taskNames = @('Windows Defender Scheduled Scan')
$preferences = @('DisableRealtimeMonitoring')
$services = [ordered]@{ WinDefend = 'Automatic' }
function Get-MpComputerStatus { [pscustomobject]@{
    RealTimeProtectionEnabled = $script:active
    AMServiceEnabled = $script:active
    AntivirusEnabled = $script:active
    AMRunningMode = $(if ($script:active) { 'Normal' } else { 'Not running' })
} }
function Get-MpPreference { [pscustomobject]@{ DisableRealtimeMonitoring = -not $script:active } }
function Get-Service { param($Name, $ErrorAction)
    if ($Name -eq 'wscsvc') { return [pscustomobject]@{Status='Running';StartType='Automatic'} }
    [pscustomobject]@{ Status = $script:serviceStatus; StartType = $script:serviceStart }
}
function Get-ScheduledTask { param($TaskPath, $TaskName, $ErrorAction)
    if ($TaskName -eq 'defendnot') {
        if (-not $script:active) { return [pscustomobject]@{Settings=@{Enabled=$true}} }
        return
    }
    if (-not $script:missingTask) { [pscustomobject]@{ Settings = @{ Enabled = $script:active } } }
}
function Test-Path { param($LiteralPath) return $true }
function Get-CimInstance { param($Namespace, $ClassName)
    if (-not $script:active) { [pscustomobject]@{displayName='dnot.sh'} }
}
function Get-Item { param($LiteralPath)
    $item = [pscustomobject]@{}
    $item | Add-Member ScriptMethod GetValue { param($name) 'Defender' }
    return $item
}
function Get-Process { param($Name, $ErrorAction) }
function Get-ItemProperty { param($Path, $Name, $ErrorAction) [pscustomobject]@{ HideSystray = 1 } }
$trayPolicy = 'TestOnly'
$script:active = $false
$script:serviceStatus = 'Stopped'
$script:serviceStart = 'Disabled'
$script:missingTask = $false
if (@(Get-StateIssues -Disabling $true).Count) { throw 'Fully disabled state was rejected' }
$script:serviceStatus = 'Running'
if (@(Get-StateIssues -Disabling $true) -notcontains 'Service still running: WinDefend') {
    throw 'Protected engine incorrectly reported as disabled'
}
$script:active = $true
$script:serviceStart = 'Automatic'
if (@(Get-StateIssues -Disabling $false).Count) { throw 'Fully enabled state was rejected' }
function Get-Item { param($LiteralPath)
    $item = [pscustomobject]@{}
    $item | Add-Member ScriptMethod GetValue { param($name) $null }
    return $item
}
if (@(Get-StateIssues -Disabling $false).Count) { throw 'Empty AMSI display name is not proof of damage' }
$script:missingTask = $true
if (@(Get-StateIssues -Disabling $false).Count) { throw 'Windows-managed missing task incorrectly treated as inactive antivirus' }
'PASS: syntax, launcher contracts, binary checksums and isolated state-verification cases. No OS settings changed.'
