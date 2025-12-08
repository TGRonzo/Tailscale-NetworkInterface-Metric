# Tailscale Metric: Startup Instructions

This repository contains `set-tailscale-metric.ps1` — a PowerShell script that:

- Logs the current metric of any Tailscale network interface.
- If the metric is less than 500, updates it to 666.
- Logs actions to `tailscale-metric.log` (created next to the script).
- Displays a Windows popup when a change is made.

Running at startup
------------------

You can make this script run at user logon/startup in two common ways:

1) Copy to the user's Startup folder (easy, runs in interactive session)

   - Startup folder path (current user):

     `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup`

   - Example PowerShell command (from an elevated or normal prompt):

     ```powershell
     $startup = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
     Copy-Item -Path "C:\Path\To\set-tailscale-metric.ps1" -Destination $startup -Force
     ```

   - Note: If the script requires elevation to change metrics, placing it in Startup
     may prompt for elevation or fail silently for non-elevated sessions. Prefer the
     Scheduled Task method (below) to ensure it runs elevated.

2) Create a Scheduled Task (recommended — supports `Run with highest privileges`)

   - The following example registers a task that runs at user logon and requests
     highest privileges. Run these commands from an elevated PowerShell prompt.

     ```powershell
     $scriptPath = 'C:\Path\To\set-tailscale-metric.ps1'
     $action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""
     $trigger = New-ScheduledTaskTrigger -AtLogOn
     Register-ScheduledTask -TaskName 'SetTailscaleMetric' -Action $action -Trigger $trigger -RunLevel Highest -User "$env:USERNAME"
     ```

   - When registering the task you may use `-User 'SYSTEM'` if you want the task to
     run as SYSTEM (no interactive popup) or a specific user. Use `-RunLevel Highest`
     to request elevation. `Register-ScheduledTask` must be run elevated.

Log file location
-----------------

- The script writes to `tailscale-metric.log` placed in the same folder as the script.

Permissions and behavior notes
------------------------------

- Changing interface metrics requires administrative privileges. The script tries
  to re-launch itself elevated if needed.
- The popup uses Windows Forms; in headless or non-interactive sessions popups
  may not be visible. The log file will still contain details of any changes.

Questions or next steps
----------------------

- Want me to create and register the scheduled task for you now? I can add a small
  PowerShell helper to register the task if you give me the absolute path where
  you want the script placed.
