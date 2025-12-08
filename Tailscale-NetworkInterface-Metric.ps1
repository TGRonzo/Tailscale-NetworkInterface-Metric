#FINAL CODE (RES)- 08-12-2025

<##
.SYNOPSIS
    Check and set the network interface metric for Tailscale adapter(s).

.DESCRIPTION
    This script finds the Windows network interface(s) associated with
    Tailscale (matches InterfaceAlias or InterfaceDescription).
    For any found interface it logs the current metric. If the metric is
    less than 500 the script sets it to 666, logs the change (with date/time)
    and shows a popup message to the user indicating the change.

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

# If current metric is less than this, it will be updated.
$MinNetworkMetric = 666

function Log {
    param([string]$Message)
    $time = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    "$time - $Message" | Out-File -FilePath $logFile -Encoding UTF8 -Append
}
Log "-- Script started ---"

function Ensure-RunningAsAdmin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Log "Script is not running as administrator. Exiting."
        throw "This script must be run as an administrator."
    }
    Log "Script is running with administrator privileges."
}

### --- Main logic ---
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

            # Show a popup to the user to inform them of the change. Use Windows Forms
            # which is available in Windows PowerShell / desktop Windows. If unavailable,
            # the script continues silently after logging the event.
            try {
                Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
                $msg = "Tailscale interface '$alias $af' metric changed from $current to $MinNetworkMetric."
                [System.Windows.Forms.MessageBox]::Show($msg, 'Tailscale Metric Updated', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
            } catch {
                Log "Could not show popup message: $_"
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

