#FINAL (08/12/2025), FINAL (16/12/2025) RES

<##
.SYNOPSIS
    Check and set the network interface metric for Tailscale adapter(s).

.DESCRIPTION
    This script finds the Windows network interface(s) associated with
    Tailscale (matches InterfaceAlias or InterfaceDescription).
    For any found interface it logs the current metric. If the metric is
    less than $MinNetworkMetric the script sets it to $MinNetworkMetric, logs the change (with date/time)
    and shows a popup message to the user indicating the change.

    This resolves the issue where Tailscale's network interface metric is lower then the local LAN interface,
    causing local LAN traffic to be routed over the Tailscale VPN instead of the local network

.NOTES
    - The script attempts to re-launch itself elevated if not already running
      as Administrator (required for Set-NetIPInterface).
    - Log file is created next to the script as `tailscale-metric.log`.
    - Intended to be run at user logon/startup (see README-setup-startup.md)
#>

### --- Safety / environment checks ---
# Ensure we have the script path variable available (PowerShell 3+)
if (-not $PSCommandPath) { $PSCommandPath = $MyInvocation.MyCommand.Path }

# Path to log file (created next to the script so it's easy to find)
$logFile = Join-Path -Path $PWD.Path -ChildPath 'tailscale-metric.log'

# If Tailscale Network metric is less than this, it will be updated.
$MinNetworkMetric = 666

# ------------
# Functions
# ------------

# Logging
function Log {
    param([string]$Message)
    $time = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    "$time - $Message" | Out-File -FilePath $logFile -Encoding UTF8 -Append
}
Log "-- Script started ---"

# Ensure the script is running as Administrator
function Ensure-RunningAsAdmin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Log "Script is not running as administrator. Exiting."
        throw "This script must be run as an administrator."
    }
    Log "Script is running with administrator privileges."
}

# Show a tray notification with toast message (Thanks JPro!)
function ShowTrayNotification($message)
{
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")

    $objNotifyIcon = New-Object System.Windows.Forms.NotifyIcon 

    $objNotifyIcon.Icon = [System.Drawing.SystemIcons]::Warning
    $objNotifyIcon.BalloonTipIcon = "Warning" 
    $objNotifyIcon.BalloonTipText = $message
    $objNotifyIcon.BalloonTipTitle = "Dude!"
     
    $objNotifyIcon.Visible = $True 
    
    Register-ObjectEvent $objNotifyIcon BalloonTipClosed -Action {$sender.Dispose();} | Out-Null
    Register-ObjectEvent $objNotifyIcon BalloonTipClicked -Action {$sender.Dispose();} | Out-Null
  
    $objNotifyIcon.ShowBalloonTip(30000)
}

#--------
# Main
#--------

Ensure-RunningAsAdmin

# Find any NetIPInterface entries that mention Tailscale in their alias or description.
# This handles both IPv4 and IPv6 entries and catches common naming variations.
try {
    $interfaces = Get-NetIPInterface -ErrorAction Stop | Where-Object {
        ($_.InterfaceAlias -like '*Tailscale*') -or ($_.InterfaceDescription -like '*Tailscale*')
    }
} catch {
    Log "Failed to query network interfaces: $_"
    Exit 1
}

# Process each matching interface entry (this may include separate IPv4/IPv6 rows).
foreach ($iface in $interfaces) {
    $alias = $iface.InterfaceAlias
    $index = $iface.InterfaceIndex
    $af = $iface.AddressFamily
    $current = $iface.InterfaceMetric
    Log "Found interface Alias='$alias' Index=$index AddressFamily=$af CurrentMetric=$current"
     
    # If metric is less than $MinNetworkMetric, update it to $MinNetworkMetric
    if ($null -ne $current -and ($current -lt $MinNetworkMetric)) {
        try {
            Set-NetIPInterface -InterfaceIndex $index -AddressFamily $af -InterfaceMetric $MinNetworkMetric -Confirm:$false -ErrorAction Stop
            Log "Changed InterfaceMetric for Alias='$alias' Index=$index AddressFamily=$af from $current to $MinNetworkMetric"

            # Show a tray notification to the user to inform them of the change. If unavailable,
            # the script continues silently after logging the event.
            try {
                $msg = "Tailscale interface '$alias $af' metric changed from $current to $MinNetworkMetric."
                ShowTrayNotification -message $msg
            } catch {
                Log "Could not show tray notification: $_"
            }              
        }
     catch {
           Log "Failed to set InterfaceMetric for Alias='$alias' Index=$index AddressFamily=$af"
        }
    } else {
        Log "No change required for Alias='$alias' Index=$index AddressFamily=$af (metric = $current)"
    }
}
Log "Script finished"
