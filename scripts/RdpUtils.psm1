<#
.SYNOPSIS
    Shared helpers used by the RDP workflow steps.
#>

$script:TerminalServerKeys = @{
    Server = 'HKLM:\System\CurrentControlSet\Control\Terminal Server'
    RdpTcp = 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp'
}

$script:TailscaleExe = "$env:ProgramFiles\Tailscale\tailscale.exe"

function Set-TerminalServerValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('Server', 'RdpTcp')][string]$Key,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][int]$Value
    )

    Set-ItemProperty -Path $script:TerminalServerKeys[$Key] -Name $Name -Value $Value -Force
}

function Set-FirewallAllowRule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][int]$Port,
        [string]$Protocol = 'TCP'
    )

    # Remove any existing rule with the same name to avoid duplication
    netsh advfirewall firewall delete rule name="$Name"
    netsh advfirewall firewall add rule name="$Name" dir=in action=allow protocol=$Protocol localport=$Port
}

function New-RandomPassword {
    [CmdletBinding()]
    param(
        [int]$CountPerClass = 4
    )

    $charSet = @{
        Upper   = [char[]](65..90)      # A-Z
        Lower   = [char[]](97..122)     # a-z
        Number  = [char[]](48..57)      # 0-9
        Special = ([char[]](33..47) + [char[]](58..64) +
                   [char[]](91..96) + [char[]](123..126)) # Special characters
    }

    $raw = @()
    foreach ($class in 'Upper', 'Lower', 'Number', 'Special') {
        $raw += $charSet[$class] | Get-Random -Count $CountPerClass
    }

    -join ($raw | Sort-Object { Get-Random })
}

function Set-GitHubEnvValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Value
    )

    "$Name=$Value" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
}

function Assert-Condition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowNull()][object]$Condition,
        [Parameter(Mandatory)][string]$Message
    )

    if (-not $Condition) {
        Write-Error $Message
        exit 1
    }
}

function Invoke-Tailscale {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromRemainingArguments)][string[]]$Arguments
    )

    & $script:TailscaleExe @Arguments
}

function Wait-TailscaleIPv4 {
    [CmdletBinding()]
    param(
        [int]$Retries = 10,
        [int]$DelaySeconds = 5
    )

    $ip = $null
    $attempt = 0
    while (-not $ip -and $attempt -lt $Retries) {
        $ip = Invoke-Tailscale ip -4
        Start-Sleep -Seconds $DelaySeconds
        $attempt++
    }

    $ip
}

Export-ModuleMember -Function Set-TerminalServerValue, Set-FirewallAllowRule, New-RandomPassword,
    Set-GitHubEnvValue, Assert-Condition, Invoke-Tailscale, Wait-TailscaleIPv4
