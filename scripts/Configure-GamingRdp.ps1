[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [string]$UserName = $env:USERNAME,

    [Parameter()]
    [switch]$SkipPerformanceTweaks
)

$ErrorActionPreference = 'Stop'

function Assert-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Run PowerShell as Administrator and try again.'
    }
}

function Set-RegistryValue {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [object]$Value,
        [Parameter(Mandatory)]
        [Microsoft.Win32.RegistryValueKind]$Type
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
}

Assert-Administrator

$rdpPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'
$rdpTcpPath = "$rdpPath\WinStations\RDP-Tcp"

if ($PSCmdlet.ShouldProcess('Windows Remote Desktop', 'Enable with Network Level Authentication')) {
    Set-RegistryValue -Path $rdpPath -Name 'fDenyTSConnections' -Value 0 `
        -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValue -Path $rdpTcpPath -Name 'UserAuthentication' -Value 1 `
        -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValue -Path $rdpTcpPath -Name 'SecurityLayer' -Value 2 `
        -Type ([Microsoft.Win32.RegistryValueKind]::DWord)

    Set-Service -Name TermService -StartupType Automatic
    Start-Service -Name TermService
}

if ($PSCmdlet.ShouldProcess($UserName, 'Add to Remote Desktop Users')) {
    $rdpGroup = Get-LocalGroup -SID 'S-1-5-32-555'
    $member = Get-LocalGroupMember -Group $rdpGroup.Name -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ieq "$env:COMPUTERNAME\$UserName" -or $_.Name -ieq $UserName }

    if (-not $member) {
        Add-LocalGroupMember -Group $rdpGroup.Name -Member $UserName
    }
}

if ($PSCmdlet.ShouldProcess('Remote Desktop firewall rules', 'Restrict inbound RDP to Tailscale addresses')) {
    Get-NetFirewallRule -DisplayGroup 'Remote Desktop' -ErrorAction SilentlyContinue |
        Disable-NetFirewallRule

    Remove-NetFirewallRule -DisplayName 'Gaming RDP over Tailscale' -ErrorAction SilentlyContinue
    New-NetFirewallRule `
        -DisplayName 'Gaming RDP over Tailscale' `
        -Direction Inbound `
        -Action Allow `
        -Protocol TCP `
        -LocalPort 3389 `
        -RemoteAddress '100.64.0.0/10' `
        -Profile Any `
        -Description 'Allows RDP only from the Tailscale CGNAT address range.'
}

if (-not $SkipPerformanceTweaks -and $PSCmdlet.ShouldProcess('Windows gaming settings', 'Apply conservative performance settings')) {
    $highPerformance = (powercfg /list | Select-String -Pattern 'High performance').ToString()
    if ($highPerformance -match '([a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12})') {
        powercfg /setactive $Matches[1]
    }

    Set-RegistryValue -Path 'HKCU:\Software\Microsoft\GameBar' -Name 'AutoGameModeEnabled' -Value 1 `
        -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValue -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' `
        -Name 'AppCaptureEnabled' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' `
        -Name 'HwSchMode' -Value 2 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
}

Write-Host ''
Write-Host 'Gaming RDP configuration completed.' -ForegroundColor Green
Write-Host "Connect to $env:COMPUTERNAME using $UserName at the PC's Tailscale IP."
Write-Host 'The Windows firewall now accepts RDP only from 100.64.0.0/10 (Tailscale).'
if (-not $SkipPerformanceTweaks) {
    Write-Host 'Restart Windows once to apply the graphics scheduling setting.'
}
Write-Host 'Do not expose TCP 3389 directly to the public internet.'
