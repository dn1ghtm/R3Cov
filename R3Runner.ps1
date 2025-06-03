# Run this command in PowerShell to execute WinTool directly from the URL:
# iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/YourUsername/WinTool/main/WinTool.ps1'))

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Restarting as Administrator..."
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/YourUsername/WinTool/main/WinTool.ps1'))`"" -Verb RunAs
    exit
}

# Continue with the rest of your WinTool.ps1 script here
# ... (copy all the content from WinTool.ps1 starting from the Add-Type commands) 