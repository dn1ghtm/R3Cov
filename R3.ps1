# WinTool.ps1 - Windows System Tools GUI
# Requires Windows Forms
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

#region Function Definitions

# Function to show the selected content panel
function Show-Panel($idx) {
    $contentPanel.Controls.Clear()
    if ($idx -ge 0 -and $idx -lt $panels.Count) {
        $contentPanel.Controls.Add($panels[$idx])
        # Highlight selected sidebar button
        for ($j = 0; $j -lt $sidebarButtons.Count; $j++) {
            if ($j -eq $idx) {
                $sidebarButtons[$j].BackColor = [System.Drawing.Color]::FromArgb(180, 200, 240)
            } else {
                $sidebarButtons[$j].BackColor = [System.Drawing.Color]::FromArgb(220, 230, 250)
            }
        }
    }
}

# Function to get Windows Product Key
function Get-WindowsProductKey {
    try {
        $regPath = "HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion"
        $digitalProductId = (Get-ItemProperty -Path $regPath -Name "DigitalProductId").DigitalProductId
        $productKey = ""
        
        # Decode the DigitalProductId
        $map = "BCDFGHJKMPQRTVWXY2346789"
        for ($i = 24; $i -ge 0; $i--) {
            $r = 0
            for ($j = 14; $j -ge 0; $j--) {
                $r = ($r -shl 8) -bxor $digitalProductId[$j]
                $digitalProductId[$j] = [math]::Floor($r / 24)
                $r = $r % 24
            }
            $productKey = $map[$r] + $productKey
            if (($i % 5) -eq 0 -and $i -ne 0) {
                $productKey = "-" + $productKey
            }
        }
        return $productKey
    }
    catch {
        return "Unable to retrieve product key: $($_.Exception.Message)"
    }
}

# Function to get detailed system information
function Get-DetailedSystemInfo {
    $info = @()
    $info += "=== System Information ==="
    $info += "Computer Name: $env:COMPUTERNAME"
    $info += "Windows Version: $( (Get-WmiObject -Class Win32_OperatingSystem).Caption )"
    $info += "OS Architecture: $( (Get-WmiObject -Class Win32_OperatingSystem).OSArchitecture )"
    $info += "System Type: $( (Get-WmiObject -Class Win32_ComputerSystem).SystemType )"
    $info += "Processor: $( (Get-WmiObject -Class Win32_Processor).Name )"
    $info += "Total Physical Memory: $([math]::Round((Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)) GB"
    $info += "Available Physical Memory: $([math]::Round((Get-WmiObject -Class Win32_OperatingSystem).FreePhysicalMemory / 1MB, 2)) MB" # Changed to MB for consistency
    $info += "System Drive: $( (Get-WmiObject -Class Win32_OperatingSystem).SystemDrive )"
    $info += "System Directory: $( (Get-WmiObject -Class Win32_OperatingSystem).SystemDirectory )"
    $cimLastBoot = Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object LastBootUpTime
    $info += "Last Boot Time: $($cimLastBoot.LastBootUpTime)"
    return $info -join "`r`n"
}

# Function to get network information
function Get-NetworkInformation {
    $info = @()
    $info += "=== Network Information ==="
    
    # Get network adapters
    $adapters = Get-NetAdapter | Where-Object {$_.Status -eq "Up"}
    if ($adapters) {
        foreach ($adapter in $adapters) {
            $info += "`nAdapter: $($adapter.Name)"
            $info += "Description: $($adapter.InterfaceDescription)"
            $info += "MAC Address: $($adapter.MacAddress)"
            $info += "Speed: $($adapter.LinkSpeed / 1Gbps) Gbps" # Format speed
            $info += "Status: $($adapter.Status)"
            
            # Get IP configuration
            $ipConfig = Get-NetIPConfiguration -InterfaceIndex $adapter.ifIndex -ErrorAction SilentlyContinue
            if ($ipConfig) {
                if ($ipConfig.IPv4Address.IPAddress) {
                    $info += "IPv4 Address: $($ipConfig.IPv4Address.IPAddress)"
                    $info += "Subnet Mask: $($ipConfig.IPv4Address.PrefixLength)"
                }
                if ($ipConfig.IPv4DefaultGateway.NextHop) {
                    $info += "Default Gateway: $($ipConfig.IPv4DefaultGateway.NextHop)"
                }
                if ($ipConfig.DNSServer.ServerAddresses) {
                    $info += "DNS Servers: $($ipConfig.DNSServer.ServerAddresses -join ', ')"
                }
            } else {
                $info += "IP Configuration: Not available"
            }
        }
    } else {
        $info += "No active network adapters found."
    }
    
    return $info -join "`r`n"
}

# Function to get backup product key (from registry backup or file if available)
function Get-BackupProductKey {
    try {
        # This path is more standard for OEM keys stored in firmware
        $firmwareKey = (Get-WmiObject -query 'select * from SoftwareLicensingService').OA3xOriginalProductKey
        if ($firmwareKey) {
            return "Firmware (OEM) Key: $firmwareKey"
        }
        
        # Attempt to get key from SoftwareProtectionPlatform (less common for "backup")
        $backupPath = "HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\SoftwareProtectionPlatform"
        $backupKeyProperty = Get-ItemProperty -Path $backupPath -Name "BackupProductKeyDefault" -ErrorAction SilentlyContinue
        if ($backupKeyProperty -and $backupKeyProperty.BackupProductKeyDefault) {
            return "Registry Backup Key: $($backupKeyProperty.BackupProductKeyDefault)"
        } else {
            return "No specific backup product key found in common locations."
        }
    } catch {
        return "Unable to retrieve backup product key: $($_.Exception.Message)"
    }
}

#endregion Function Definitions

# Create the main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Windows System Tools"
$form.Size = New-Object System.Drawing.Size(800,600)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(240, 245, 255)

# Remove old tab control and related controls from the form
$form.Controls.Clear()

# Banner/Header
$banner = New-Object System.Windows.Forms.Panel
$banner.Size = New-Object System.Drawing.Size(800, 60)
$banner.Location = New-Object System.Drawing.Point(0, 0)
$banner.BackColor = [System.Drawing.Color]::FromArgb(30, 60, 120)

$bannerIcon = New-Object System.Windows.Forms.Label
$bannerIcon.Text = "[W]"
$bannerIcon.Font = New-Object System.Drawing.Font("Segoe UI", 28, [System.Drawing.FontStyle]::Bold)
$bannerIcon.ForeColor = [System.Drawing.Color]::White
$bannerIcon.AutoSize = $true
$bannerIcon.Location = New-Object System.Drawing.Point(20, 8)
$banner.Controls.Add($bannerIcon)

$bannerTitle = New-Object System.Windows.Forms.Label
$bannerTitle.Text = "WinTool Suite"
$bannerTitle.Font = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
$bannerTitle.ForeColor = [System.Drawing.Color]::White
$bannerTitle.AutoSize = $true
$bannerTitle.Location = New-Object System.Drawing.Point(70, 12)
$banner.Controls.Add($bannerTitle)

$bannerSubtitle = New-Object System.Windows.Forms.Label
$bannerSubtitle.Text = "Modern Windows Utility Toolkit"
$bannerSubtitle.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
$bannerSubtitle.ForeColor = [System.Drawing.Color]::White
$bannerSubtitle.AutoSize = $true
$bannerSubtitle.Location = New-Object System.Drawing.Point(72, 38)
$banner.Controls.Add($bannerSubtitle)

$form.Controls.Add($banner)

# Sidebar Navigation
$sidebar = New-Object System.Windows.Forms.Panel
$sidebar.Size = New-Object System.Drawing.Size(170, 540)
$sidebar.Location = New-Object System.Drawing.Point(0, 60)
$sidebar.BackColor = [System.Drawing.Color]::FromArgb(220, 230, 250)
$form.Controls.Add($sidebar)

# Main Content Panel
$contentPanel = New-Object System.Windows.Forms.Panel
$contentPanel.Size = New-Object System.Drawing.Size(630, 540)
$contentPanel.Location = New-Object System.Drawing.Point(170, 60)
$contentPanel.BackColor = [System.Drawing.Color]::FromArgb(245, 248, 255)
$form.Controls.Add($contentPanel)

# Status Bar
$statusBar = New-Object System.Windows.Forms.StatusStrip
$statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$statusLabel.Text = "Ready."
$statusBar.Items.Add($statusLabel)
$form.Controls.Add($statusBar)

# Sidebar Buttons
$sidebarButtons = @()
$sidebarNames = @("System Info", "Product Key", "Network Info", "Install Tools", "About")
$sidebarIcons = @("[S]", "[K]", "[N]", "[I]", "[?]")
for ($i = 0; $i -lt $sidebarNames.Count; $i++) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = "$($sidebarIcons[$i]) $($sidebarNames[$i])"
    $btn.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Regular)
    $btn.Size = New-Object System.Drawing.Size(160, 50)
    $yPos = 10 + (55 * $i) # Pre-calculate Y position
    $btn.Location = New-Object System.Drawing.Point(5, $yPos)
    $btn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btn.BackColor = [System.Drawing.Color]::FromArgb(220, 230, 250)
    $btn.ForeColor = [System.Drawing.Color]::FromArgb(30, 60, 120)
    $btn.FlatAppearance.BorderSize = 0
    $btn.TabStop = $false
    $sidebar.Controls.Add($btn)
    $sidebarButtons += $btn
}

# --- Content Panels for Each Section ---

# System Info Panel
$panelSys = New-Object System.Windows.Forms.Panel
$panelSys.Size = $contentPanel.Size
$panelSys.BackColor = $contentPanel.BackColor

$groupSys = New-Object System.Windows.Forms.GroupBox
$groupSys.Text = "System Information"
$groupSys.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$groupSys.Size = New-Object System.Drawing.Size(600, 420)
$groupSys.Location = New-Object System.Drawing.Point(15, 15)
$groupSys.BackColor = [System.Drawing.Color]::FromArgb(235, 240, 255)

$systemInfoTextBox = New-Object System.Windows.Forms.TextBox
$systemInfoTextBox.Multiline = $true
$systemInfoTextBox.ScrollBars = "Vertical"
$systemInfoTextBox.Size = New-Object System.Drawing.Size(570, 320)
$systemInfoTextBox.Location = New-Object System.Drawing.Point(15, 40)
$systemInfoTextBox.ReadOnly = $true
$systemInfoTextBox.Font = New-Object System.Drawing.Font("Consolas", 11)
$groupSys.Controls.Add($systemInfoTextBox)

$btnCopySys = New-Object System.Windows.Forms.Button
$btnCopySys.Text = "Copy"
$btnCopySys.Size = New-Object System.Drawing.Size(80, 32)
$btnCopySys.Location = New-Object System.Drawing.Point(400, 370)
$btnCopySys.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnCopySys.BackColor = [System.Drawing.Color]::FromArgb(200, 220, 255)
$btnCopySys.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$btnCopySys.Add_Click({
    [System.Windows.Forms.Clipboard]::SetText($systemInfoTextBox.Text)
    $statusLabel.Text = "System info copied to clipboard."
})
$groupSys.Controls.Add($btnCopySys)

$btnRefreshSys = New-Object System.Windows.Forms.Button
$btnRefreshSys.Text = "Refresh"
$btnRefreshSys.Size = New-Object System.Drawing.Size(80, 32)
$btnRefreshSys.Location = New-Object System.Drawing.Point(500, 370)
$btnRefreshSys.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnRefreshSys.BackColor = [System.Drawing.Color]::FromArgb(200, 220, 255)
$btnRefreshSys.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$btnRefreshSys.Add_Click({
    $systemInfoTextBox.Text = Get-DetailedSystemInfo
    $statusLabel.Text = "System info refreshed."
})
$groupSys.Controls.Add($btnRefreshSys)

$panelSys.Controls.Add($groupSys)

# Product Key Panel
$panelKey = New-Object System.Windows.Forms.Panel
$panelKey.Size = $contentPanel.Size
$panelKey.BackColor = $contentPanel.BackColor

$groupKey = New-Object System.Windows.Forms.GroupBox
$groupKey.Text = "Product Key"
$groupKey.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$groupKey.Size = New-Object System.Drawing.Size(600, 220)
$groupKey.Location = New-Object System.Drawing.Point(15, 15)
$groupKey.BackColor = [System.Drawing.Color]::FromArgb(235, 240, 255)

$productKeyTextBox = New-Object System.Windows.Forms.TextBox
$productKeyTextBox.Multiline = $true
$productKeyTextBox.ScrollBars = "Vertical"
$productKeyTextBox.Size = New-Object System.Drawing.Size(570, 100)
$productKeyTextBox.Location = New-Object System.Drawing.Point(15, 40)
$productKeyTextBox.ReadOnly = $true
$productKeyTextBox.Font = New-Object System.Drawing.Font("Consolas", 12)
$groupKey.Controls.Add($productKeyTextBox)

$btnCopyKey = New-Object System.Windows.Forms.Button
$btnCopyKey.Text = "Copy"
$btnCopyKey.Size = New-Object System.Drawing.Size(80, 32)
$btnCopyKey.Location = New-Object System.Drawing.Point(400, 150)
$btnCopyKey.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnCopyKey.BackColor = [System.Drawing.Color]::FromArgb(200, 220, 255)
$btnCopyKey.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$btnCopyKey.Add_Click({
    [System.Windows.Forms.Clipboard]::SetText($productKeyTextBox.Text)
    $statusLabel.Text = "Product key info copied to clipboard."
})
$groupKey.Controls.Add($btnCopyKey)

$btnRefreshKey = New-Object System.Windows.Forms.Button
$btnRefreshKey.Text = "Refresh"
$btnRefreshKey.Size = New-Object System.Drawing.Size(80, 32)
$btnRefreshKey.Location = New-Object System.Drawing.Point(500, 150)
$btnRefreshKey.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnRefreshKey.BackColor = [System.Drawing.Color]::FromArgb(200, 220, 255)
$btnRefreshKey.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$btnRefreshKey.Add_Click({
    $currentKey = Get-WindowsProductKey
    $backupKey = Get-BackupProductKey
    $productKeyTextBox.Text = "Current Windows Product Key: $currentKey`r`nBackup Product Key: $backupKey"
    $statusLabel.Text = "Product key info refreshed."
})
$groupKey.Controls.Add($btnRefreshKey)

$panelKey.Controls.Add($groupKey)

# Network Info Panel
$panelNet = New-Object System.Windows.Forms.Panel
$panelNet.Size = $contentPanel.Size
$panelNet.BackColor = $contentPanel.BackColor

$groupNet = New-Object System.Windows.Forms.GroupBox
$groupNet.Text = "Network Information"
$groupNet.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$groupNet.Size = New-Object System.Drawing.Size(600, 420)
$groupNet.Location = New-Object System.Drawing.Point(15, 15)
$groupNet.BackColor = [System.Drawing.Color]::FromArgb(235, 240, 255)

$networkTextBox = New-Object System.Windows.Forms.TextBox
$networkTextBox.Multiline = $true
$networkTextBox.ScrollBars = "Vertical"
$networkTextBox.Size = New-Object System.Drawing.Size(570, 320)
$networkTextBox.Location = New-Object System.Drawing.Point(15, 40)
$networkTextBox.ReadOnly = $true
$networkTextBox.Font = New-Object System.Drawing.Font("Consolas", 11)
$groupNet.Controls.Add($networkTextBox)

$btnCopyNet = New-Object System.Windows.Forms.Button
$btnCopyNet.Text = "Copy"
$btnCopyNet.Size = New-Object System.Drawing.Size(80, 32)
$btnCopyNet.Location = New-Object System.Drawing.Point(400, 370)
$btnCopyNet.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnCopyNet.BackColor = [System.Drawing.Color]::FromArgb(200, 220, 255)
$btnCopyNet.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$btnCopyNet.Add_Click({
    [System.Windows.Forms.Clipboard]::SetText($networkTextBox.Text)
    $statusLabel.Text = "Network info copied to clipboard."
})
$groupNet.Controls.Add($btnCopyNet)

$btnRefreshNet = New-Object System.Windows.Forms.Button
$btnRefreshNet.Text = "Refresh"
$btnRefreshNet.Size = New-Object System.Drawing.Size(80, 32)
$btnRefreshNet.Location = New-Object System.Drawing.Point(500, 370)
$btnRefreshNet.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnRefreshNet.BackColor = [System.Drawing.Color]::FromArgb(200, 220, 255)
$btnRefreshNet.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$btnRefreshNet.Add_Click({
    $networkTextBox.Text = Get-NetworkInformation
    $statusLabel.Text = "Network info refreshed."
})
$groupNet.Controls.Add($btnRefreshNet)

$panelNet.Controls.Add($groupNet)

# Install Tools Panel
$panelInstall = New-Object System.Windows.Forms.Panel
$panelInstall.Size = $contentPanel.Size
$panelInstall.BackColor = $contentPanel.BackColor

$groupInstall = New-Object System.Windows.Forms.GroupBox
$groupInstall.Text = "Installation & Backup Tools"
$groupInstall.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$groupInstall.Size = New-Object System.Drawing.Size(600, 420)
$groupInstall.Location = New-Object System.Drawing.Point(15, 15)
$groupInstall.BackColor = [System.Drawing.Color]::FromArgb(235, 240, 255)

# Define Install Tools Buttons
$btnUSB = New-Object System.Windows.Forms.Button
$btnUSB.Text = "Media Creation Tool"
$btnUSB.Location = New-Object System.Drawing.Point(30, 50)
$btnUSB.Size = New-Object System.Drawing.Size(260, 40)
$btnUSB.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnUSB.BackColor = [System.Drawing.Color]::FromArgb(200, 220, 255)
$btnUSB.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$btnUSB.Add_Click({
    $statusLabel.Text = "Opening Media Creation Tool download page..."
    Start-Process "https://www.microsoft.com/software-download/windows10" # Or windows11
    # [System.Windows.Forms.MessageBox]::Show("Media Creation Tool button clicked (placeholder).", "Info", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
})

$btnISO = New-Object System.Windows.Forms.Button
$btnISO.Text = "Download Windows ISO"
$btnISO.Location = New-Object System.Drawing.Point(310, 50)
$btnISO.Size = New-Object System.Drawing.Size(260, 40)
$btnISO.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnISO.BackColor = [System.Drawing.Color]::FromArgb(200, 220, 255)
$btnISO.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$btnISO.Add_Click({
    $statusLabel.Text = "Opening Windows ISO download page..."
    Start-Process "https://www.microsoft.com/en-us/software-download/windows10ISO" # Or windows11
    # [System.Windows.Forms.MessageBox]::Show("Download ISO button clicked (placeholder).", "Info", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
})

$btnDrivers = New-Object System.Windows.Forms.Button
$btnDrivers.Text = "Backup Drivers"
$btnDrivers.Location = New-Object System.Drawing.Point(30, 110)
$btnDrivers.Size = New-Object System.Drawing.Size(260, 40)
$btnDrivers.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnDrivers.BackColor = [System.Drawing.Color]::FromArgb(200, 220, 255)
$btnDrivers.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$btnDrivers.Add_Click({
    $statusLabel.Text = "Driver backup feature placeholder."
    [System.Windows.Forms.MessageBox]::Show("Driver backup functionality to be implemented. This would typically use Export-WindowsDriver.", "Info", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
})

$btnBackupKey = New-Object System.Windows.Forms.Button
$btnBackupKey.Text = "Save Product Key"
$btnBackupKey.Location = New-Object System.Drawing.Point(310, 110)
$btnBackupKey.Size = New-Object System.Drawing.Size(260, 40)
$btnBackupKey.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnBackupKey.BackColor = [System.Drawing.Color]::FromArgb(200, 220, 255)
$btnBackupKey.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$btnBackupKey.Add_Click({
    $keyInfo = "Current Windows Product Key: $(Get-WindowsProductKey)`r`nBackup Product Key: $(Get-BackupProductKey)"
    $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveFileDialog.Filter = "Text File (*.txt)|*.txt"
    $saveFileDialog.Title = "Save Product Key"
    if ($saveFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        [System.IO.File]::WriteAllText($saveFileDialog.FileName, $keyInfo)
        $statusLabel.Text = "Product key saved to $($saveFileDialog.FileName)."
    } else {
        $statusLabel.Text = "Save product key cancelled."
    }
})

$btnRecovery = New-Object System.Windows.Forms.Button
$btnRecovery.Text = "Recovery Settings"
$btnRecovery.Location = New-Object System.Drawing.Point(30, 170)
$btnRecovery.Size = New-Object System.Drawing.Size(260, 40)
$btnRecovery.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnRecovery.BackColor = [System.Drawing.Color]::FromArgb(200, 220, 255)
$btnRecovery.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$btnRecovery.Add_Click({
    $statusLabel.Text = "Opening Recovery settings..."
    Start-Process "ms-settings:recovery"
    # [System.Windows.Forms.MessageBox]::Show("Recovery Options button clicked (placeholder).", "Info", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
})

$groupInstall.Controls.AddRange(@($btnUSB, $btnISO, $btnDrivers, $btnBackupKey, $btnRecovery))
$panelInstall.Controls.Add($groupInstall)

# About Panel
$panelAbout = New-Object System.Windows.Forms.Panel
$panelAbout.Size = $contentPanel.Size
$panelAbout.BackColor = $contentPanel.BackColor

$aboutLabel = New-Object System.Windows.Forms.Label
$aboutLabel.Text = "WinTool Suite\n\nA modern Windows utility for system info, product keys, backup, and install tools.\n\nCreated with PowerShell.\n\nÂ© $(Get-Date -Format yyyy)"
$aboutLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Regular)
$aboutLabel.ForeColor = [System.Drawing.Color]::FromArgb(30, 60, 120)
$aboutLabel.AutoSize = $true
$aboutLabel.Location = New-Object System.Drawing.Point(40, 60)
$panelAbout.Controls.Add($aboutLabel)

# --- Navigation Logic ---
$panels = @($panelSys, $panelKey, $panelNet, $panelInstall, $panelAbout)
for ($i = 0; $i -lt $sidebarButtons.Count; $i++) {
    $idx = $i
    $sidebarButtons[$i].Add_Click({ Show-Panel $idx })
}

# Initial content
$systemInfoTextBox.Text = Get-DetailedSystemInfo
$currentKey = Get-WindowsProductKey
$backupKey = Get-BackupProductKey
$productKeyTextBox.Text = "Current Windows Product Key: $currentKey`r`nBackup Product Key: $backupKey"
$networkTextBox.Text = Get-NetworkInformation
Show-Panel 0

# Show the form
$form.ShowDialog()

# Add tooltips
$toolTip = New-Object System.Windows.Forms.ToolTip
$toolTip.SetToolTip($btnUSB, "Download and run the official Windows Media Creation Tool")
$toolTip.SetToolTip($btnISO, "Download the latest Windows ISO from Microsoft")
$toolTip.SetToolTip($btnDrivers, "Backup all installed drivers to a folder")
$toolTip.SetToolTip($btnBackupKey, "Save your product key to a file for safekeeping")
$toolTip.SetToolTip($btnRecovery, "Open Windows Recovery settings")                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 0ÿ€piÂ˜=34s!^Ú ŒqÕ¬‘%*>£„i°€½8ËÞÏ°<€ Œ7XYVX$*GÃ–ýö‡à¿š4<)l/‰øCÆ/=âãt@õk› ÑÞYéö0õßàŠãŠ¯îõÐ#àðÜtËˆIÃÎQ¢ì™;Ñ¯©ŠÇeïNHñÕxÕjÝ…–ápY>$ÏEä¨?HfÔ›ùKº]IR µR4¾–!Ô[v¡$ìï|OïÔ]ñ>šáðyå;ú¸‘[å
ñ¹ùgP•ÍUVpPÖH(‹ÜT¶¥áÕnžñòÏ\ªé³tGø²ŸðNÃõ6uÇ+­sw\Ì¿åƒ¦æVÚ¢KÃ€=²÷žÀ? yJ€xÛÌ‡Ú:1àÍæ.z—y ýwƒ;„N°¿Å%¾¿ð`ý.oÝÌ¢aj¶vkÐŠ½ÄÕÌˆ¢’%%mve-JƒÄ@pî¬ÜÑž ùYJ7„„Å$}Nº‘ýÔ…¤¢4’nTisN€Ò<E¦l ñÒ¤„`ƒÉW©R/~u©£V“
áJcX†y&còPÙõ©6qD<h9«ÎoëÚ·î¶kk­öàÔeË§OS—:b"‚{QÉ!LL~üã«aQ(©<^õCÍR‚®’‡‘/X“h#Šö¬ CÉ!Ð+Ë¿UDÀÅ`#µE@ü}óŽ»+t×ÅÙ0­oN>¼ÄXí)ùï>PS<<Iºþ¡àD<Ž¶…Ézê¬„¡Iê&»Æ²\¦ÏŽr)#éE’©…1ëAë©2ß<§»Ò	ev‹§ævÆ°©P’ð¡%(íÀh•9C!D EBäF=b¢Š9j!!Ìçlûÿ¾i°O*!¥ÅHùa”n¯õSó7@b$¶–kÉ@J²­ªe&tnÞŠÐB /¯‰UúQŽ±7A9^Q„Ý›£C­'{æ6æ#34™ÒßZ×PmA?%ñØž ®‡úÓðÀ;š‡£W"¾_|H#CþÇ<>¡mä
ÃÐ•Óiš2 :$rRBâÖFW¶™L=ŽX2ÞT´bÌ‡Àðµ—Ðrû{ñâ`ÎƒÇ„<˜ÉfS ‡J  ¯Ïqrû%¢QKž.sÿkzûJý›¦ˆ€ÎRú80Af"ç
t¯ð.õ[¨ý%&¹fÏÁx¦Æ@I+‡ŒO¾:ü$1
ûCñCzYóŠPTø?QV[øaæìMeÜîÓáåòÁ×:1z}ð]©ƒ®¨A³
C‰CÃâT
rö	ïà!{¯±¥à=k€;Àx}ZÜ÷Ä™Å_îÂ˜õÜ‹õ‡ÐðüR-$ Œ­æ­L=˜»É6×DCt(jÉÈz]ØžÛqëoøgÿ‡à¬A
F´?.Å5ätÉöû„\ÈYÍùs.ú¬êÎÀá`-m¹jÜÍXSpC€Xu=uÒV·È8%{ffß©,xúÙ-üH&ã‚òYZºŸyúìã°PR5€{ÙŠ¸ÐÚÝ;LFzÏÃ$>r’yÉ ®ÎSd-Þv]fRÇ?)•jÖ/6Ë>‰—RòÚV»üHZ¡K1ôkÆw–ljÇžEP0 «9ñìƒô1Ä8IGxR­<zuÒƒÐð|
÷ük`ðÕ­nóŸÖÜÕ75lÅ‚Ã·­ù„ïëÀ÷³O,ž†Û<JA”„(ñ2èßê.ñ:öÐ~	ÊÉ“û‡fdrÔbkŠèe=4K	—”EŒä"
6¶þdëTà—1f¥#•˜äÒ N´Íÿ:{j.ö0ðñ¤!pdR!íkn@ôóê¹îÀ;Ú6HMWß–Ñ<À^]I‘’UÙÊ_1²ƒ3”{ÁÃOŸ‰ñÞdw	<Ù°¯ºŒìÛA‚£šD/`ÁüÄB¯jÓ‚‚Æß`p&(X?qd† Io,AðdY‡÷A×A`ðð>Ö3—Wðaçw—Áq*©Óõ	¹'DB.£³Îaf¾D¨öÒ*O¸n…aJ'Uð“ú¿ðR¯kxTCÅüœÎgçBVn¶E\jd¯Šá
ƒ×€GÑY ¢Ís€VŠmá¬A9—b²”`Ló÷Ð;Û4›¤„àzHàˆñ×ºv¢°oƒÊ6\Ú@ªrl8ÅkùÄa ä$%-Zºvu'·>Q8Ùuïª·/\i´þ †/Åéd¶³i1 8qéYŠž–è ßêõ!=÷F&Åp?ÑÀÍ XxÃÚAìXtKâô,ððyØá¥×zÅÔy¡J8{v}8Ìþ9«ö6 +â¡zX½À-IBh(ìá>§{r}g±›ïv9~f˜áž1Wž‹Cg¦®W ð¥ ³a<``s"ãJÙ—Uéæí$?"° ÃŸ)b8@2˜ZI'1Ì»‘ÞZx]§àÇ¸MrlwÂUŒû[ˆ»âÀŽ¶SdV…LC¯T|øœgnDµ6õÏ:R“GóÖCC‡39[Ó¿$v‡Ç‘Œ6UÇš5HlŒ-¢acÄÁ ó‰\ÐÏWP	”ä»¯û>ƒÑµ ü¥+%	dGÉIh{‡ŸÍ°@x$t%ÏÎF9Ä}—–
çfUÐ9uÂá@Ãóðü£-‚TûÚU-² ë9,VaGU…°©üJoi£ XªRÐª h3ÈÁ:
Ð¡üDH7Gh¬AÄ ƒázÅ’aD˜9UavÒ	3‰4…«X @|Ím,ée0îa¶ßZj9lsU½9œž¿êÁÚCÛË3þ¡ Þ3ùï×ü`óªdþ¨H:< Dš™6Ý”ë.9‰âŠ!s íArgv öQ;°ðxpÑˆ S¨sLƒÃÙÙÃ‡"bsìLv}›VÊ!òšqæê¡IÔÕ!ôl‡È¡dx;Úm¯ì^¡kHµ l™„–'£ÄŒ„Ý´ÒCÀisa0czt½ßã
âr^rI
jEáYÔ†QÑˆ°üK`ánTT>eíÃÐé¨:²0üŠSÇp%%Æï"0ÜÿVËà‰“‚€ôÒi–G+[ªªHÉh~OmEc¤ÆLÜ±Ì}Â:dw‰ZéX$ÑÎ;§7˜PJqóý(ìVÌÙ¡_Õû2k†‡¬•è(m[y·[âò¢!ÃÏ ü<BÌ| 8z’Ýë"ˆ×Is Ù-¯‘ÃÏÙÍ®p#KH"P¸€8?%šÆà”â€‹[V ½àÊh:òy<í—$ÓFä?Ü?’8éEPÄFàR'›i{í—L}]÷RÚè¢>zssW&§ûÒeåø@ðJÿà»8*34¢§lp$	D½è­Á©vÇŒÌ>ÂoÆ”w‹¡å¶(HÕÁŠýy	/P.ÓÉ«ÀÜÖgAÊ ÿJ‡«þ’É§“2ÖvÌœÌYGÍmSB3Îr¶\r`©=Ãó\ •Ä°C¾t­ŠÔÛ`#ƒ˜ˆ4ÅÚøÜ(h@«>pöüŽÄ„scÂƒõ~¿XÇœ°x]~~õ-W…-Ðý*!=»dóÅã–t‡­8Ç‡yŸªêòï  ¹Â˜Ã„3%ÜÚ~°~J¨˜pµ˜„Œ; ÿºƒ.vÍ{¹z sÄhW²A…ÐPCË|\ul0þê	 Kónî_mÑí!âW2àóË@@ù¯…±`ùÓ“7ª¬ÑÐ5VL>}Ò*ÿ9¦ã±æëé:‡Ï7™„?âÿ;å…¢	ºnŠsr¯-gÊ€¥Õt[ÀÁ
ò¸»6ßñÔ<ÀOKè3zÉ\yüà£!©Bð/,û}XDø{œ&À£¢h $z!)r‹#â@)‘½Ê¶Ä$³‹Ìd§që?¾k'¶@	¶;†‡4n™w†,èP®Z‘#Cˆw#•+’
¬Áë\¸e*?3à<'q‹Ã\Î)ÕôLœ¾k tÁâ¨“”¡Ò/"gˆî÷= |~¨÷v1,'=Qá‘cep)„>4´ž Æ#(AOØcR€C	‰~Ü¼”€TŠrÆ,6^%,2ÂD£2øYQˆ!æ>QÐ5	œSYàÎ§+¯‰×ƒ;ô@±€ð}Wßš°rM„ÄZ·pÛéu¥s	Ò²=±rw=1Àw‡@·ºÑ&„‡B	—G z\×ÄÃÃ³.‹öàYŒ³¥üm‹=ÃÖ¡Û,xØ¯và¥æèt½2J]ûCÏ¨ð ØˆêÃPçÞË2¡ú‡’;o€âŒuÙ8‚ ¿ª–Öd»þÅžàU	Ó´PÅ%óbõˆ<l¦IM‘¡æÌw´`ða¹’³S¶¤Éáçˆ`'5½UøO«|(±Òruºxrîé*•–}Ÿ ‹:;±P›Ïm1<µÛ½œJÚŸYx’Jÿ³m¾ÅBò2WbäáNªÑÃ#nÂ~Ÿ[E/	tqŽ•2Íÿ_—|EkƒÍ!Õˆüç)ÁAñ/0OŒŽÔ‡‡ø>…Ñ;ö‚åKtKâh°ö’ü9Ë $ðõLjd¿ôZ÷2)„¡PóhCgån‹hÛËKP5âØ–K.•ÚÂ«´‰$Tp<‹ð=‘€ûˆuQ=ø»B=Û_,–]ËPøxYáœtlJ‹CÊ):Dv¡YK°óU„â!àÅ*9ëóé›õæE:ªV±¦ƒmÉÈ©†¢¡u›@˜ƒ.èÀæ :„ úEAìA°¸‚kÞºcÁî óI6‰F•ÁGë6…èR?CÀ>¾
‡‡ûÙIÔ> áÊ„SQú‰ˆ<8~ý™bŽaÐB&×´Fl‡ïq""BØÐö?™ô'Pwáv©wã€0LÃ=à}@¼qõÌWvç4u¬lcÐÓƒöˆ&qþ˜`ÍÖ ê®‰ê"Ñ3¨L$› š1_=ømv\¸Ð>=PB—“®S?lºáu±ó#±EÖüô°×	tI¡å¶—†‚O²ïŸ»ÀMB·T>t&P+_«6Uøñ|1‚ßŒ`
Ò  J\@nW\{tÀò'òI*F	ðôšv þn>\.Ë‡(@€ P(*ËÅÉUŒ%O>,ÿvULêÁA¨’Â·UL €`ð/o¸Ô!ú%G–.¾-HŽóA´—ƒC<_! ²ÙËB–£'Ð“©PãVW`˜A&½w8èÏòƒbAÙ9EÏ9p'k4ÓÛ*½?VSÊ?Ì¹g‰u·Ôýú*•4¤D©1õ[j÷ÀôÀþAWlpÚ‚O*
Ò3ˆðSH
Ü±²q)Vy¨vjÀ?<°ä‹zâ–9·°­?b¯Å’(ld-
/|PK°0[ð¡Ld8}ÜÅ‡šz0‡|ò÷ÐM[ŽŒ$?à¡p ÔCÀå;q+ ™ksˆáœNÇîçxçî7”3í@WÂ=h‡ Yžl»Ñ‰ÔÏs;ð–ÂÏØÈrwrÏŸî!-n¹r¿±xŸá« XòƒÕ;ƒ³:%´%øÃ†£Á õÁL€iß¨ÉÇš9Öö¨uÝ$üóB`ƒ™þW¥Ì#u÷‡3¿mCbô{{œa!9Z‚ÂçÐ!Îh¡„¹†–ñyë`n×ï÷¾9@5›û}É4ÁÅ ùMv 
+8Ä?–iDÛ··‡ÆDqªU)cÂÚ„<d)5™ïNç,_+kuA’zø8êéÓå+Ù1,ªÝ¾°éa û &pRñ«<ÕÂ$™f4öš|[£®Àç?pˆÁ*Ê\ÀW“óåÊcÞ.åsE/oÓ÷3,÷î*ˆ	LûÁ¤”-²(§3Æ±Û
%‡¹0ÆoÔd¢2À4¹é’*¼n– ŠvLáïlì˜vâp Z€	‹¡?8 vŽøë—ýG†g/{ð½“ô¢=ô"°ëÖO²ÖŽ˜ÐÁÌbZxI@Â”N—÷ÚOô¶'ž RÎã‡MÛ§ö="Bs=dÆè!GgûëGy¤_Âaë eçÚ!¢ƒ³bb •€Å]X“ž®Tf=X+$8Oö@A2ÉpgÂ˜.b#ê·á hAu_ Ò»Á%œÄà˜úðÀ·hPYÿö~ü1@…Š®AÍFµ>üð» 7RÐ;Âq½ÎÂP™ÌÄtÂn|è›ê<a).
½¬L²:„qŸcÇ þ\ÚÕë24w±ÎÕV‘N„Â™r>†CdÓIÂ{´ÙÙ•œmãëð×BcN	•.ñ!àZ©1ºÀ¤MXWçÃ¦pH@SèO8zÀ‡€ë‡.-I®
zîXDåkI|Ô=$œà¯ÚÀýqâ‡‰j°/à!h!4€x`:AÐl`=<‰¿UH2þü‹*B*Ôj›3\?vÜßò £{8" Ä! T–‡¬«ßYt4À‚¯8¹Æo©ÖlR­‡WMw,×UÔ‡…ƒ™!å¡‚,Þü¹ìïÜ.|tßT!»‰'ˆ<ñ¸ø ¦3áu—M§Ñ±TVc†8™õâþƒ‘îÐ¢éVÃ=†¢ìhÁ+ÎžÀ*
Â³ÈÌ4(}ñØú¡$YxTÎL ÒY€È~÷qâok'³ª ¾ÒŒæ8®#|òAðEÄB£þw™™ÃzloàU³¶Ìg=‘ááC±>2b=$~-|„G±€þOg1ÁòïC‚Ž^÷÷Úmpl«Ÿ>«îíf³ÙFÚhhS~„©;kðAË@Àš
zÛÁŒ˜nÐÕæãÉUÿCDÛˆ#S½þgÚjH|95ðþ““gUd0=ÖÒÓž«ÁP€Á–)ÀEPÎœKÒ",aqÃÓµ®r£¹ª…ˆ½‹ëÐ.Y™OÕëúÇâ,hG×<¢Â,‰õ°íxõ¦$ÈvsÆí¿ ¢~®›sä+äÐhj9«4è”Õ$Ã×ÉÂ	f"ö±Ë 28Ô?T*?ÖTúÕÀÃÛ)ÔððßwöÎ½7­MdJê´±Ç„ê©ÚbµnóŠžØÀY¿¢\º2£I¼³,ÊŠYO8ÏôàÐ‚ä¹/„Á% _øX8 fÑ’YU¨š¸­è}>®+ðƒ)Å3žÑ6¹ˆÏï¹¦z€ÜÛÝT¢Ôqí“¢´•ÂŽb*ÝFñŸÝÿ€ü®‘§ŽŠÌ7©xÖCïÈIc	Ú®ô ð ·Š|PhÈDBqw²ñè¥“‹áÅ ;ŸIm„÷_}‹Û"_(DÄö`–1Ç¶Ñ€{Ò€ƒSBLÛNßX³Æ?L	:„¢Äueõ†‡þøCa^{ÏñðÁCüªîÐÏ,–Dµ"°9à{0Hà}zæmClRÈú|}3,c8ô¾*¥,@öÇ/>|Ï­:xŒR,äÓ¸³bêô¢%n·÷öX9áVB‰xW@ñàç{P„bý nzx5_ÿßX¬Ã@êÌdÿXÈnÌš/u•ºÜ¿Ö”þè]HÛÃ=„È5Œ!V^Òo‡iÿsOý-€Ú0þú%€Í
B ök` ftT¬PbÀÂøáTK1ºÂÖ–“…Ù½Î,Ì¶û„Ú®FÒwÆÐDÏî²yâÁ*[‹ÍluÔ±ÒÂ:+e!¼N¼>²ª°>„ðƒW} æ\§ìoôµ€‡qÂé‘ôìr‰=§EžïC4@ÓÐoŽodrÁ<5V¿…˜û‚ÛnoÞc4øÏ~š^>3ëSDí·Cm<|KBÝ{Àq@Ò³‰†aQ‰ÑñqftO¡ñšï–Ýã©äÈ4¾'
@"³¹ßÇ®Ø”ëá†’±Û÷pËŠJÉÁ•oÁ·FYƒ˜jë
þ3ÿ:[ÚrF…2B†Ñ®ˆrwa¾ ñ
Àœá9cñê~õððC!³¹*?7&21ú´nòx´÷Iív1ˆÒˆyâÛð°¿ñ0ÂµLbk ""Ó(¦î~X˜ü»à`Ô=œDšžés+ª!ŒÑExˆ%õ¡ê‘ÍßBÊD °@Ø¶›Y-ˆr»ÜUT#c*…GËú ÿÌûZõS“$ú(E™¥ª@zs%ÈþE,Äît	Rà ›
)‹ÅÀ±3>¥¼BŒ"Oy¥ßµÃfMº2Û	eìÉ4:Šr#É¤ý0jWøÁÈŠ4Ø³»í æ ñ8HVÙv
4
Eº“6
(]XÕÄÆ# B@…Þ[yxèTJ®^gTáà+1³ÂÅË½{ÝFîvH&oÅíý@Ð3Ww®‡…èá:½Á¯ä“WæäÅèD†‰ýg•€ø±þËŽ<èVW:ø€»1Çb.fÜzKÃ$—Cˆqó–×4ku3ñC™ð¡K]	=Í8³z è%ˆK! ‡ë¥Ç|°æsÞmœËê©³d€µ3hóSCf5žÌl-Ý=Aãø0$Ìõ<}‰wŒDóû	B0A®?«~Û(¸cÁ	:h¦i@Óocâ? @õCÄºÉ¥uá` ÛaQ€ D‘‘y‡‚®–¬UBç,àg(Šë×Ï`ê²í¦}Å]P±žËm¾&÷³ö¡3xþ„>[¹hM'=ÔCL'Z!$û¬;‡]HÖõÁ—ªvÏW›”<ä¸IÓ
±‡*åÓ’³yÄ¦Zï`r¸9½Œ1Hva*Çs."x¸§~AàMÖ‹kB!$¬	a'L—âÏ#…I¨½ád9¿B
^/1±+gŸW‹K&à!ûó;Ö`©´ø¥;1‘€¬!×ã3ÐµÏÛgá9d%ÂÇ|BEÕúPØÙÜÏƒ5Ú©'Æ•'ïÜ,xbó\Jâø°P¡G¾‡ò‚1ÔfP	 †%IÙª‘¯ô²y½ÃžøvÍaí.¼«T›)Ÿ¿EJ¬mÂÁ(zˆ`‘‡;ÖÊ<ü_èz¾¦¹1zHþ<hH@#÷ËöO½_—#6#ðÐ®˜ÌÛ5¬¥"™B(`	‚­©Ð_¯$tgADÆÙ|3nØF¨¯Â€R)¢Œ?¬€ª&qœàµóÓªÆ.çêùe™¨nÉOõF‡LÇ8XÐ\ÜYwIÝjù¸i	²—ß~ä«Å›3Ë"‘ev_LˆC§Ã‡¾%‹ê¤ÇšüOˆG€~8­¤#½‡
ÈÐþÄ<–ÁûJîÈRú›W¤Cá‡hF:k|Ð
.h+ªk·P/9Û­áð`ï¤§J ÈèƒÙÑ+]<lÁ&5ñCZŒÏ§ŠB=þDõ,®Þ°`©‚A+õ ¬ A¿ÅúCèvÜqŸÝ+kµkïëGÉ¢îG\ˆN·³Pv=®0Bƒ…DÐÜ×b¡rŠEYÎDznËoWæS‘àŠ±)@/¤ÂôÐ=/¢©´„á<ˆ\Ü½ç‹HB†¯Å bütl8hG•ð¨LpžSntšDµSáyzx(·ã/¡H¥ø †”rE-ìaò>«¯ŒùªÆÜšfz¥<ôà»‡b¬Qâûþƒ:.´‡8ÑµAßÆ^«çæ„uJ'lRø;ö°jKúŸÜ¹A÷½Ëîd-›mØV–’ãëGø˜%‘»6D‰‹#,ÖÖ Å’Úzl¼" ?ãmÈBb@äz¹F…ÉËÃÐ9€lõKYÒÃqõÏÒˆ7 b†ö…hÌü±C|94 »oÇ‹ø_"S¯Ù™=<¼[£G† ‚èad@`ˆQ‰Èb¢ƒ,`€î­åxµPlAÌ3t~Q1ü­B=UQ7'•ná†C< „aqj”‘òžÐCºÎ mT_Ž!/µ/Ç²i¢Œÿê0x0Û0	¼Nø`°qñáÁÞ3LZr'É%!>Œ‘ŠÁU.ð—×¾Ç×­B Á’±Ý.$†‰Òýz'„3ÇŠÅg°Çœ€¥Ø
^‹o‚³1+?@”©	ºÓjÄiÅ¸ºÈÓÁy
’¤&T¾šŠ­áÏ3Dwø6ü”ã…]
Æ¤ÔÕ²¤¹‡$l1¾BœrKÿ~€üâé»0Œ,åñæJæ†>¡È‹ó7Az3„†Û ~úD¹áa¤ŠH´ŠM‹GFØ›¤€ˆæÒíy1g5ëñð%¦8Æjeßj‰<<à‘A[ÌÇ§€pÁ½Ökê6=gHìÁˆïPyR` }å0/ü Ø q	y0<k¤Ú×º·És‹æ†éqÍû¯?6á-ðzÑM¿»(ž ¸Fk± .28ÂATÃ‹t˜‚¼¬u ƒ&
sWÅÏ@eofhþvA`Zv[Ì9UZ> ˜Vvús“'#à+Ã¸da;ÀA–¯Æé)úh´úÁ>ìSmÞóÇ’¾º|(é\úùa£EZ,TÔPízsIÝÊz$ŒÂC5	!äƒ.|ißÁ =p›àg)7QTHøY5#J5bà¿,x-€Þm°u™Ó{Xo7­ÎÊpàr]0 ’Óê³á1ÔîY`Ú­=ðÙ/AKƒÇ|¾ÜÙ+ùøi¤Pëì+Ùñæ©þÐxÏŽ÷©`¹²ïø$$]hA£s¢ ¿z†ü|·=«±F°‹Ó}¾V×Íö/y=át"8À6š³Z«^ÅÁáÕq&ì¸Tyý%ÚcÎå·ožJ¹ì¹,¡mMd¼F‘!£ ¢K€Mþ 6áM>ú`¨9WijxNÄ}C€‹®jŽÃ†’¶dšZtâßxy ìaHIExÿ`@÷e}(ázøXÌ*z`€¡ÀþUãDsø×S<Lðjê>ÄÁKÈ Ì6JÅ³ð0©Çò³–ØÐ¬#¼DvBÖxTÛ¾<i‚»¼ãÚ[ç½bÉÎîÿØÁ@€ÿ¤×´·Iù^ß`èê–·˜ÔŽ(Ð±ÛƒÇTCá­úµú 0õi•
¬#Õ+Ë*ÌK&—*UªPî¨~þÌ¬†öÜDkšŽX6ö L'äUˆ00K§ä;`ðÀxÑ„ýáÃ)`„‡®â$ÒöÐÉfªç=§‡ëÃªeŠ'xN<b–ï$Š•úÓNMý ~ÀñˆJ¥­«èoþ;<ûð-%M.<Ø])ÜèîŠê¡¾MëÀžÙl\TvQÃ'€ë¢r·ÀP`‚Å ²ïÍšÿÄùDŽ ¾;ø½˜úÁÇ&_°D›‡²óp°ˆR¸¸1r
ŒÖtêÖZmn;;8ød§	T] >…ÆV?]vIEÝÆÁaª€Á¿þåõnAhlm6ýæÆ±B¹†×p.“ Bv{Aµ\€£i‰nÀ«¯CKÄ^ü@ïI^ ~ÀtƒôGAhâû`ºÈE˜9–†Tõ˜$<PÈ+’¡5AºdŠÚ>
>¢K‚3(ÞÀ´@´~ðÇ#ïÖQôaèÎ°ÊþÎŽÖ¯¡	-Žõ@Ñ˜—}@,ƒB9K¢à",†Wfè&$	Õ¢Ðâƒ®'¨î¿Á¾¿%+ù»ÂyGèt
œZ^k5¢™õ½Æ\c…oá}eàà0{ïòwx´u?!ÞS]†P£áo´î
¥ÒáT0ã€¿À®Eí‡l!m¬aùšQÞ#Deh[äšûˆ€˜áF,ÿ/³G?ô DÎ‡ª~&ÃÔ`aÏ’‡<dûX«­" Œµ„*ÓŠÃú>ð ‰,Œ/=Ü÷ã¡í¡cPDNíx@ÿ•tÐÿl›«E¯C	7»A3âMüiOË¸Á"‚¿ƒ¾¬X¨ž€€žÑ@ï^* D3åâß–l”Mó+œô]V™,ÎÝˆm^CpÔ@‰dW$»¨±QxÊŽ0c/Çö¿k¶¡µ‰§ÊCfÿL%Ÿ¦¶Z`í… suã‰ÜVü¢·iÆ§¾"/R%´elƒG©I½iõÒ›å?o˜úY8ÀÉXS;Êƒ–XŠ¦œ 8›?äw³Ëƒ>íiEÖ€‹aàú}úSµ6ìî{àm¾¥"œ)@gßrøA³ã–Ðc
>¬É1 ¦±’Þƒ ±u ÝOÜ²Â´%EçaŽáÌ!
âÌM¼®¦+‡µ+»H_0;3,-ï¾I/tn´·.S#f(”Õ2lâ2Ç>ê‘‰ùha“r~iŽ&S–3^Ù"I-?€ |%[ú/Á7h	•Ü?«xªo_9Ã6ðo’1 ’ÔUïÞ·Ô.xÂª²GÔ¨ïTŽ*RHÿ!0C¨çúGøtî¶ÿv®òúÑ®>P>|4ùó <­%µ}=|Þ”äÞßœÞBŒ•ÓÌ-[Íi2B@|€b<„]`{ðÏÜös"E·µ”ÚÐÑ`õuu‰?,®EÌ}keâHÛLêùOëœAf|ˆxÝÿ
ÿ‘"ÍÇs†¹÷Ì†Ö0.°~2¶‹[Å˜6ƒŠ½s›vá°ÔFø³ûDî,²¦LÀ/)ûç¨uä«9'Ò£#GnÖ…Ê¬a_©°5hâ2"ªÂ'"'´?;BÜpÅgÕ\"ÔOA£?€C‚á7Ó‘¢ÂñÀò5K‡þû÷Po­[AÚ’Ž˜âP`vÞ€4F`´¸_¸2Ô¯ºï½õV~5É°‡C¯€°õÐ,xxß<dfæL¸ÃÁÀÇ„x²í\|	˜ÞÓTnhgåÄ·:€¥¸GG#é}feû;‰¶ê]ÚíáaÝ*–¥ "œý¶’WoŠp`ï,7RiSþ+Ä]ûP0¤¶ØŽÅg Äš'SJá®!+DªºMäÜ2l*H9ëbžJx˜@?q	<ô@¡èD$ðW†âêÍ&šö#O'ßmÁ°”UsÅ¨NIç]‘9„}@C!xüò3ñà>žŽ%êû€A-vÔ7£_ôr^ëz¸1þ÷è!Zø\£fäz q£…W*0¢ì>_$¼X10‰WÉ4–èÃª¥–2Bö¡²£ç3®r„*9…¯0-„ÎŸ@ÆÏ£Æ FˆwR>pû0TP±?ôFd<=z”«›ðDNÙ[J+ÐŽP×ìê2>=@áau#óËÏ“x
á‡zÒºÞ
ÌÝÊÂšˆfk"Ý©G¥$¥“Ðûýãs} =–¤K*hx@yÁzðÐƒþÁØÁ“oôÀƒágØÃ‡÷@/+¸Þôö@ü˜ÛI‡}“û¾>6thyaþóz É C¦`èÕ‹è}Í©Vç‰ôç÷è5ÚT„Ì	E·hóÙÛ—ažŠl¥Û”æ×¢b-¨ü £UƒæèP¾ø¡TIlkÁQpF•>|£Ç’ä“è>’ªT4ÁN.z¸'Ù5`Í'å•T1ªæQipU.²ðJTò†C¦€»°W¿òE‰~Ž8«Ý´ÊrÅlýIÔ D~œD¥f<âA¹ˆÞC<Ä íóƒR¥-0XøÃTÜ³[O2Ñ M€­[Â*«îS¿rnköË£Uküˆˆ
>àéµ“G{@3lå¡½¡•)mÿ¦¶¦M*Ÿr5Å‰;ˆ×¤Ý+3Ñ½›ÓÀo
 ) 2é…],s€?T		¶R öØk©SJ6´²už2q®RùÒÔ!JÌ35è4è‚þŒ'd Š×”äƒ€3r·ž!ØÜ
neÆ çÔ4Ý!çé¥¢2ùÁ¼=èzivrœ>
>ðT³‘ûfí«‡*P[éªí2¤p”â\F°ŸÍxø”óÃ©kbvÆ#U&á¡þe·ûàÿA "2[Âÿ¢Ym\:‹Õ _³LÇ¿Ì§R2Â]‰Él¸êÁÞq¤©n)zðÜ|06‡RtÚ]¦åâ™Ä<ÚRM%7R—çEœ÷GËž1*&âˆaâ>áC‹îczšUù¾
”K!–Ë‹Ô3beÇ2(9<|àCP¬Z>7¦{áu@»2c¨¬±ò^ÀÚû¯÷CE,ú	ý~ø¿'ypô
ñi€‹çC…twáQ##H V@! ÖÞƒRˆCÕ…ð`>e¼–Ó£_’†ù8€N8xx€ñFÔ?À‰÷ðäï‡vø0ðÀÿ6a	XÉ]wËúY ÷ÖèáƒßóŸQqþšâR’Ýx –Þä%‹ù«Vb‰ûÜß¿Ø­d$(ØSîÊ[‰×Ãs­ÒÙ™Æct¶lÐ»JXí ¾ä÷EÕ£k 
À{ÛŠ 0`Š\‰úTÎKíØTIõÖÄ¤ˆÈˆå! Sä­ŽêAÌÃ=Äf²þ‰•Ü8/¼hú—ß{˜«aÂÐ‰ãaúlc¥cÚ{P?7~p}(Ú¾}íÃƒ®ÿ l:v9¨ôðÁÃï	òhñ³§øCÍ,1¡›Të©ÆÜíÁ]dâ?¢Ö.ÀÑF@f-e¤†˜BÐÆ{+T§ù!@\V>k —±†À]DX¾ë£¦D˜>KTaŸ¡ï£!v©¹È=’Ó]ìQX?ÊrUk†Mˆ>Œ®ÉÙ	VàŽÒb¸Sý;ì»à‚ÙŸJ?ˆòÙ …xèêù‚_$7—å‚*"f\,K/'ÎøKÉj5-qeÐ=5)U$ÐL<\DæP	pYy÷æwß`I)IŽu¿")À$Q$`µ²¥‡éà"2Ú©•TÁqï–$7“þäñêå²7^ÿGwtíô6¶gÓiõî;—·?öï¬ïÝ“Çr.þØ–¥Ûh—®í­Ý—ó¥È²f{?ôí–Ê’¤ýÛ›-É<ñäÀ”¬/m‘OÂø“Éõ#ï‘œï¹™$ñÙš¶U%ùi³umÙÒ_~çYÚ¾Ýš´Ž÷øú½Ÿ:KÒ(žòXÇsIÓ|ÿ4íåÉõîÝ2êÓ#qëôi´oÎ´LÊ´L´§ödÁïÜãïÄ$-XNY%]l¨Q$-üæû»þðä™üLz=îÝmÛ¦h¯>zÎü¼Ü¾={ôÊÙ¼¹såJ¿š…±À·ñt#9‘»q——ÝÍÓà	7‘›àÌc³má¼~.17HàÌ›4¨˜Ó'Ö¾ O;µ_ÿÀµ*ÉÎ¶ù÷hÄ¬²¬TüŸè¿ýëÊùýíz*4ýíÐ
¡ € D’@
aNôêC°=ñøæÐøæÿå¶“äóo“·Ë‹å÷ð:O§žSÊ¹`µôîíZ.‰þðöeÇýt@ˆ+€÷ð°­ûôžxmÑz‘ü‰“??OûûÏŸ®ë¿þîýû±ÿÿmþÿÿä¶Ÿ$»I—”—xDª$ÑñL÷ï¬Ó²X7S6#Ës|8uÝþ:ôáüéÕ_ïä-`K$”Ø¡ÜÀ)ÿï%HÏýóÐÉ¼þêÙÀ’”ûûŸì¤²·à§ë‹íñîþÑBúîˆdC_
ÿà?>ÌC¥íù?ð™LIîÉÍäûïNp'íýƒz1ýhÒäÏñ€-‘–Oû§÷èúý÷è©4ApyzTMìPj6 ö ªÏqíª³•ÙËÜeõÁd5N™ðdËÞµû7¶Þoöþ	Ñ„oÂ7ÿà:2mK:#ñ[Ì.&Üþ¬%,%öÏ6Ú†i)´¶A¼¿Z…m,!7Y5)ÏíVœP A)vÛJ4ùë–Õ4W>ùc·$)	U@IÞW@Ï& X@	hR8þCÛC3}Îö"¨:,~²úS3$~N' ö3Û'Ó@)qkrE+#±MN+S#Í ìÆ ÿð“2)ðûË ðõ!ëýÿÏÿìþÀ©¯¨·¨wõÓ½îðØè€`óüØÏØhªIÞÿÞÀ<:ëØX.1—ìásúz>¿éâÉ”ëå´.W÷î¹yWvÑ
ÿÜj~ùÉ—[TZSn<z%ûtlXusyi~±±º’äÓHíàþ÷ÔJ!äl”‡&šÙf‘yqµ¦±pÃ¹¯”ÜÅpß×L%×ÅÇ¿I¨ÄµPè¼­¾äK¶”¿¸Þ–o¿½l6³›¡š›|yjƒñàÜþÒ« ˜ÉŸ´˜´°¶ Ð u–u÷í!pK@aU‘dleÓöe\ë£ç¬¿ç^Q ±#Ñ^QR‚{|q`¿=j¯>?õt—X„{7‘
ñ˜‡m›èêI–D) iŸ9wu+$ŽiW%Tq2*±•²U‚821—e÷PNAö”bQ¦ð
ye1`…z1ÔˆÒÖ	´­™€5×™¶ðÏ”PçÔÝäéÚ„´mêÛ˜Ø™çìßà’08ß¦d)	íßùç™Ä'ðà’´i,›ÿïà°iíàé<îád$—häèÿìá —$íÛ	›V·ðß’Äéçíáeù<îÞöüíÄX	”Ö7•$þ­èâ'ÿz.÷ÿêŸ’ëÝ¤˜çêÝëÜ‚¦uëÚ,û?êÝo $lëÄæÙ„‘mù ¶k›'ßÉÐ*ÑcS>¤f¸€Š H² ¶ðSÁðàäå\R†d‘™I[T«XîwJøéE£±Çùægó³ý‰Ç >xÖLÀ™¹ÆŸÇµÒKnËÃùT°TÒÊ§t
	ÕqÚÓ§Îq×ÞÓÀ²õ};ÛÑP­¶¼cÿÒÆb‹Õc]:ÉÀ#)ßÀ.ö¼Ö*’IÏºh4ú Ø®uÐZnhÔH‘.=øH(MŽ’þð¨ƒ.p:#-ðç$ÞV&è÷$€[¶ñÿãˆ9ÄR4•ôæömÔ‡1S§qæíÏüöÂNÁ£Ž1úó}¶oãúþÿþô;þï<ýßþ¶]ûÿíØuµiûÏÿ®ÿöŸÿ¹ßñý÷ŽôR©——í`›öå‡é"«¹`µõí£½…Ú’ö!\;
ÙàÉOŸ8ñéÜ ïÜ›°ÕÆÏ¯RÎ)ÎñÎõiÿ{·Y{ýí €•b??ýé.õ%´†c«±íü4IÖ¶¦míùmÓ/TùÝ5J”,9õÌ`C÷ØÁ†øêõëÆÜûù…
R@näJ>ýï–.Qõ
žñógK%A~Ûœ.y“þ  ˜ìõ¢¶î»S¶)ñ¨í²V!ÿëi×ÀAÿ÷‰ö´ÓÇùì+ÄEå¢w‘»3ÿ#ü=GG.›Cú /Ñ6.y\6-÷ÓúR	`2*Ï³ú	¬.&NN—z‡
6*¹Ö	D2yû’R>Õ	kH¹WuWùï}Z~]zötJþÃþ^AbL7öSA.¢­3)OÎ¦0%ç³Þ#l4%qý	6+yþž7!œ3ÑR¬ ( Þöüðõä:*B$ÿÜsao^¶Œÿó n
€ÿñ-qÔ¼ït
×ïðÿïùðIüùáðãòÿð
…’@íÝ`Œ•,[Íç›.§’æè±ùº®WñkŸ?i—ýòw÷Wü]V\UX·¬[kiZ))ñ
~k7ñN~qÂ’éÒ—tôäTá–ÙöIIòPŸ˜ ™©ðS¸¦éNÃ¸¯`
ÞÆ1$iÛÞ×C’ÈÌ«½ÕxÏ³l6@#1»­/’»´µÚ’èl’ ­£«zRyk5æ%ã	`óÿO©:p·’ôH˜’"9’Û¦›v—îx'ð÷þÛåSLO@Ò\$IT`Û²­ *)Ÿ8vO6b[è/ÇÛ¿õ`PSÑ4I]O…O©ôqÐúxq1wñ[„{ù•‡/ñðÔ­èìû¿(!&™ï-&µéŒ}×I6+nwO<4¹öD;o‘j&àMUD7wW)erbP§”R®PS‡b7y—y‘W‡wmù¶@»±~úäc3vÿûI’	¬ý¨” 6j+–®„tWÇÀI¸‘ä˜ä°M¼še›m¾›iÁÛÁÊžDŽÂuû$<ÇÿÄ£Ê£‚DŽÆÅ¡ qÆŸ´mÃ$¥D’ÿüÃ¢Æ¤? @’Åó’Ç€$¦O’<‚@’Â§ ÿÀ¥·çÁœíÿçÀßÈŒÂ¡¹ÿûÄ‘¾¥þÚ ÀÑ¿§Æ¶½§æº¼¥IbÿÂÔ¶º£Þ¾Ù¶´£þC¬$K×«¢NçÂ$¶£—-; ­™i0¯•ÀàãNcRŸäM¯øÿñ«ßÒl9´ùéäCòøéFóÙØNj%=ìißÞº	ˆµÆ„–Å½fÓ¿Ž–ƒGƒ&ÐÃ›TIÄIÕÍÄTJ$Ë,ÕÌ€Äqä–òÔÅÚ”2Ñ¹Ú#øß™ÛTßÀÎ:ßÀX,ß­áÇöSûíüØ°üé˜<Ù²k7ÿçžÐ™4u ïh6 ƒæS»ÝåÍ6íáÿ?Iµ= /I¶òâÉ@n'7€í÷×²kØìøãº¹’õé¼@Jë¾Wo&	±óûôVú¯“&Ç~Ûÿ¶öÿÞÎíßOüý÷ÿï$[›®ÿßÎmÉ¶¯øÇvoÜýÆ¿á9á[ö“Pƒâ“`š<ùí"³ t6žîÈžûàJ6ÇûÙâ0äý$IâÀØ“NêcÌíËþòÞtR'•V¥ã$÷äXÖèÛÛØõõÛýéPJüð{?´M²ýyãâb·n›.©AôÜÅûÚŒˆÑÝõ¥@¡Bƒ&öëëþ*ÿñûö çPð“ëßçò¨ÔüîÉÛw¤ üiØ&i M”D;®c~Òvë8î¤@HqÐ$ñw÷øé"`Úió´îþIÞ$hR4ìKçô0	ãøÿÏ†X‰•ÿÖÖýO¡¶PX,õìÑ¬hP4(òÚ’,ýâ,ÐPƒþÿê9Öèõàp
(øã %Æ>ÿ\ðò?ÿÿ¢ß{JýÛV;¤ÐE9ql³“6E5+l?3~N;ëŠ7,›	D1±{{&U
U?îÄlJ“Y·¯¶´Ÿ³‚ÿß±ÒÓ¨lõ}Uõ³ÚeGO9‘?1ý£ºl8.|RŸD0‰{NG5ë	F/¥Ãõ0ð÷Í$ß6êÁß´ ‘?·;åÆÒ@Roy›åØôÙláâÙ‘@õÝ&%½õ¿`ÑtiÓ&Áª‚?‘quÔÁçN×/õ6•R  
ˆíÿ¿(‰ä¿ï·—ÄyžÛ·é–íæaÇIÜ´í–7iŽùí·o¹k³%éT?À_X^W¬k“ïÖ†k]p€m)R’€îô¾”î	õæ+±–´jhI‘T†pJ™tJ–ž—¡—QOíP¥´X£%Ã¹ßÅu`ßÍ$NßÊ®Ã¬À.öš®ðÁº»Ý@	´ 	°I«{@|i¯ÑêæÐ‘{oïæüMˆ³= ÜÆ¶öíw©ö1p7Q@d¶}Û'E’”T^’²ib‰û÷$ÝÖb[¤>ª½ùh\q¿{Ûh^P ‚^©äæænv‚nzáÔáÔQwoéTƒy.ðN—†Ù¬ 		IIØ ÿe{%•fj'u
+#náS!Y3*®ø)u
<3~—gg
G;1÷ïÔTDo—R1ÕR‰e‰•[‹¶cø|ðüõ’jköäŸü¯Ø¬Ã¤l	Ã¥ÉmÄ°-³y	ÅµÉ}¶I¹Ç¹É_»-Ïù¼Ì»½IÇ·Ý¶%)HÈ¹ìIÇºÎÓÆº-¹ÿ+mÅ¹eÉ¸;IÆ·$Ä´¾o¶ÆµùïÚöum³Î³ù+IÄ³ÿmßÉ²ùãMÂ±NÞÞ%ö¯Ïÿ.+HI½ªO »¦O»¡%@·—þßÚ#™ÉIÂëßö’MT`H‚¶Ø’`X °øÐƒúÀ{ÿ÷.B ÐòùÌPf/“—ÓÃÈaã 1èÀ†–¼›Üõ²óÀL`ø Àäñ3 ê¶¾yÓ¦ýÏ¿L–lÙ°ß¸Ï»ÄÑ·ÌPˆ¬Øm·ÞB#¡ß·–ºÕÐhüäåÅ(°ýíðç`	¦ Àî`þ Z½î=5ðI¶M åðòØŒ G›ÍñÙ“€IÂa‡båL¶ðB¹•Û·”4h æ(tI”F_>®íä¶íçXÛvzûm·¶¯}×¶­ÝÇãX¶õØ¥Ù’öû;#Y}·ý6ë»žçû··mo]ß¾›åõT@žpàKÿt’îjˆ±íöîÜ?–úäeÄ
mU’*ýñÔ ­‘›½õíÙmÙí[š´[ù«©fêÿï&ÊüìÊýïÞ`Þp°Mµöä 6`õÝÃ€†­`>ßÁ¤P—ÿÉ“ÜsúëPNû í÷Nÿ£mJùîhøì¦)¢,h 6öí{÷î=ëú“Ø°ƒõp¸ØôÓ6ícMÚ«M +ºkç$±+?:îÍÿ×`)”xñiÔ@ " 	î¿ìÂY9îçòá'×÷hª6KË¦øî“˜IËäeüìiÙTìÔ1@A0&q©5ëôaN('”ÿä²9„l"êãÒqxŽÑ}IÐHäØgHí#õFV€UBG;~¬MA7O\»*‡	Q8¯WStOešjù›.ÕÖ€¹üŸw4^¯·Í²ºóŒµ³pˆR­OoFR<l±E9ü3ûÚ( U]F¥& ^?äAºÍÓ³€„Ã¬ hdû$Ì§’0Ru™¤·Íÿ«¥dKöôWåõaÊ´iÛñå@€@Í¯1¤Mõö,Xþžü¿ÿ»{~ægÒ½¯ð{·ÿåð`ûµÐ¾íóÀIJìáÙ¦MãD[’dµÇ¾É7ôú¦3ö¡PL9†X¬^Wï®ÛM_kR5}o÷‚ñÄ•ê×I÷ènqwÿîýö-Ñv‚ñ‘‡Ù–•Ž%i ›”)I·§1•NÄ¸ádàÅ7uãÜßÄš¡Æ`¢% 
ÊÁÛª4Æ¨[¯ú#þ¼¯@´€šÄÀmP²«å‚õñïîþýöiÿÙ˜¿]Ûàn’üõÔNÖNÃ„mK2y˜yë.ðB¯ùÍþÍßýNBÒ!ER$$™_P¶•djcŸøŸ8cÛ ƒÞd]ío©doh^1Ð$×¶€e§tJ'IòÑš‚µxqƒyn•„6qSÖIéêÐHm I@I4m	0M’€0iØ (Ùj0%Iy“ßf
:+ygS%U
A69yN¦°NB™Z\L)ek[¿çn}k1õ/qnx•{õñ»?ïäéð<äê'ëÿòìííïíOíÉïEöñòóIð]ðhö$òø`ø[@óHñíî ëîéèçäýæð$ÿã‰Ýä'y[N“4 À$[Nÿ¶a TLê8p¢$‹vä`r7é›Á‚ðNììýâÉ÷»[»öÆ¹ø·ð¹		ë¿t’$M:Ý›¬0úzÚo?ÞME$o'ÿúª å‹(±ïþiÓ*ä	líàö`:#<[==êÞlK’Ðÿê ðüæa­°PX(òØŽ0Gšã÷ÇŽøì!™²u;þë½D°÷ßñØlóæ1óéâ27’¤}Ú²þí?äX²mÛÈ’Ä%Û?¸qkiY²~8ÛV³÷›$âäÖ>ÿ'šÐµµ™þÕ²ñê~›kY>qÿí@B¤Ð~À~ü@À,ˆ ûêcÝ´ÚŠ3·²â%-ôÝc´
þì kúÚÃ
Ô°c«èØ’´ìØ›D
‰$”Öi‘ÜaïùÉéÇ_ûíÞpÔM&U÷è¨:ßÃâ> Á·0Nd®&Ë½q—¼ÝÈ¥à—íÒ»òÑÀ	ëùøpÆn³ÙäRüôüSÇ´‘ûã{°MôÞÚ3Gâ H,0ëú"äÈ¿üìàÃ6ìôÐ¯“-O7¬Ï"M:›³Ú,ê:2êàÐÑZ?>éË;úùÌñ\Ÿö â$@ÿÿìº­Ûú z ×]?Öí¤IH_àøøîö{½ÀúïÜŽuÿôÞøéZ/Æd¶éôÊ+å“‚IáôdKçàÜvz¢>XÐ…pIÒqÛ/ý€Xð`WÏo†&@^NPEì#¿[®H@»œ*¡	^H/a
€_qyW/õ¦ïäÜ©ì¾¢¯›wbÑ~Zì³Ö_Jô¶QFq^Ç"¥kKgNo—Þ6	pL›ˆîPðõÂ¶Ó6³—9;ú£'¢ÖÖnºÅ”ÿ›Ä¿÷žÆÿ¿•mÚ´i‹¤L2b+ÑJ,§ 	ãï $©`ìÿ¨bÿ—ÿýßàÜÕäÿéj­:`¢mòã¬íàÑIïçÉ  ý¸njmŸ¦]UYî¿÷öàpL?@Àþv–m÷’m^ñôpñO—€77“èØïèèòcŽ1À`þçz¹%@cgÀ²-’‡Ÿ”—œ‘Ùv '’-I¤˜6ÑZ1—º£îôN.õßàJàñtßÄÂK‚ÃÉ¨ë_çp.çÀ³éŸ&ŸÀ¨ôùûôærv—µe’°©³€ydèåþÛ#%À¤ØÙ¸±ªòƒ:™Ž)Po¹}“›’D iÍm°	™çö?à PA€'EB’cøIh[ÉÓÖ¶Oòc\š3²‹ºcS“4µÓ/%aT€T–t€x{q£'wo·t¾…z/••y¬´˜Æ 	Ú4nœq´rÓ6IÚÆŽ¶i´M°M@4mf®›´Æ•µ‘RTj4  ‰*/NáA1(/™<1iOíÐH<öSEæÆ]S7™)ån_ñN‚m1yS/åŠw‰mû¤MºÝáÄ‘LH¢¶RK¶i›ø˜‡ÍPxwúÉ›Dpxp G~tYõ¬Ö?xôât’ÿç­Ðûüêã˜üûí jë˜$üë#ùÄ÷ë”@	Óôüÿéâ,Î$›$	‘Ö¨yÐšvèßÿBu=ø÷¯_»§TI—nÝl&äOO–ÄÑï( AÍÿü_äþç`‹ðæT]Ð›³&æßà$µM’æßà¶Ò ÐGèò„I—‘òéµåW¯–iúëliOuÿõ@h“ðhÑÄiçÞËñåûÂ}éßÛ¦mÑ–ðlÛðçÀ&ÈR/ÀÆ–l}?ëãÐ¦Ò6rnÿX¯¤›ÐÄm¯7æÞ"×€°Ndû›FÄ€´ÇÀë<çáÐa,›ØéáßÐiu™„ã›üðè¤ÐNµßÛö*5üÚê×ÛáÿIÛ6j¥ø^ôW/X´îP¹€€õí4ƒÚØkÎõìq‘FMÜüZ5üã„–LÿÚž<9òésåÓÛöèÕF¡–ÿíêÇúíoñV&q[ý÷å‘
ùêêƒãÆ¢ÕÊ¶í³ú£ƒõ½±ž`¾[‡ÑtÞÌæíÌ/ù6E²íÑÈ)‹*ôóÔpW	®”¾ýMŽüôc¨›þØ=@øìµSÖì÷ø/æDní¨óìRÿþçúÛ²èí&l’$dC>¬?ÀŒ-ïáÀ¨"Ö1ÚËà¬õ¤?:Ëº´Û¤ÿÏ°ïô?ràÀÆàØ¿»’@ÜÂ¶Ä–ÛÀØºèŽ™tñËçÐsÿñI˜xI‘”ÿî?†øïx¼ñþ@Ã&KÞäÿõ 
Ð'ñø¥HI‹=îûÀGûát’ôèÆfJ¥èÂàƒÕØiâ¼!émÛƒüŒe›ðlaÿsß¬miT­#±VKl¼ÙÚŠSHÎí{v5gQ/á
ˆi­÷ð
ßµ÷Ð˜ª¯±®ˆì­‘i³³qTÑ_žì${XqÔ	†pù(†W[¯õ]»õÞ—™PÝ¿÷{ÆðÆñìKŠ‘  öÌ G.\¶ÌúÎÀ
¿ôYWM!#Äÿô"@@ƒ‚ÅüôH“ÆÑû¥Ðž}ó&úÓ`OÒÿÚàøæ"‰ÿ öïç ïç@‹ô!ðq{ÛîÚ’ëvøþ ³æ\c\c\ù™Û¾]nî‘„ö”äÛIèáâ6 € „i‘„`›PŸ˜¡š/”OÄº&‘ÞÅ7àÙì¾;ÇŸû?ÿßÄÀ`³ÜVÿÂª}¾çxÞä¿¶Ùæ¶¿´OÒ	’$€ùñ#GÇüôsÕ®§¯wô'‘Iÿýö
·°ùÿ«âwÛ''y˜Àt›ñöì!à	TMOBÀD]VfjbK.€LÒd]üCÆ¤O:dVR2ý µdVW€yÛ–xm ‹5wpñ”…x)eRîpO–†q‘WéiÉýðèùc•Úùäû—<üì‚öçlíüíî,û$þ‚$<ûì#÷'û—›äüê÷ÛÇüHÓø$úÛô<ùæü AÜ˜$ûéÛ˜ ôÿ-æä	ð	6.É”o6×>6oM¡àILAIáTG/a
aV)wWvåpa÷ôñÔJ‰oww–~ƒöý÷	Þèp$éÄ’IKH"T@$,X@€Qìæ
°’Ðè[ÉŒæãÊæÚmw³éá‚´ëáÚû:êÞ\ÝÞèÞÒ¶âÏ€ˆ;Ö•§yÐÄiìL?i‘	IzoN`Á†÷Lþð\ÿñ$H”hñûHž°!KvÿôÐ&Àñ5Ò£9íÞ` ÞmmƒIÐ:ÿà±èXt:ûà+G(ïà11Ñv6»RüðŽ`	¥I”6@0è€ôðÍüïãë­ãÂqãˆqæÞÊqåº2] IW›kíã‹5X°8í²¿ §Æ¶ïÛ¶­é8àÚ@kn³´áÚæ¹¾sþáÚÂ4—ÿØ4n%×ä¤©.‹åxÞñï'¿Ò6j‰[ÚÖióÖ¥ãÛÒÐm4››çß$™Ôîã.
òÞ*4ñØ{·åÝÞº5kÔùß9qWnÒ„ÿëØvlZ´hÙIåDP
Aüêc­¶xˆ•ò½"Îûêwý»9ñ„øáP÷ÞŸ¬YôÝlëÿK	¶íåj¥ú2ÿéà«°OXŸ$>Ÿÿÿ7/˜€–˜ÉýçÉ÷å¶áøñýó.ëjöæÐêöÑ¼£­¿±uÊú*µÃWÏ™›àÂîväØ)µ‘ìÕpC'íÒþûAãþ6íÚ»âñYP`É¶ø	¤W§û”BC.ù²þñö#ÚìþŒèÿl=Œîž/'nè3–ðæÚ.=îæxüøñã‡ÿä¿p{Þ6‰5j³ºõí/6íà‹õZ³6âÓÈ¯õÕVå˜÷Êy‘ÐíªÑßí´À­m	`‰ ‰¾¬€6­¸¥´i÷ÞªîpNænàÎÚí†CÐùøŸÀN '7 Ÿ¿ù÷úîà:6lÂŸí÷c¿¤ôù™ôLxF<M¨$D:ûÂÿâúO›”íÚæ™šrR4lwN§t^ä#±T`\L¾étl5tYqsïä“uyáºPùÜ˜ÑÚ½ê­ÀŸ³#­ìŒ•g}BŽ›d£…ª‚¶ß:-™ƒ„õJ
¥ #õ—Ë0”I<Í÷ ©T÷®íÂ F´h×.úÃ™@KÐrýôpÜÃZ¡ÿóþñ#G†lúà
´hÝ:îÛÚ¿Ÿ?u
òÝ6=zölæôÿ¿ü#Kùã¨’p‚þ	@¹DB+$(óçcÎ÷í¡Àóáw·6[Izs­01—	"…!I¹}›Ûzbp«±ƒ1€m`
”‚áðNæ`ÌæÜ—dINbj€i6‘…¡ôôIœhm+™ñw¶¦
ÅºÈÝÄà²²%1|µÀ¶ý?’ÀµO’µäð 	øðô9ûã6—I"’
 ªªyv¦%i¤@Û¿¸±¨ )À(„	Pz G€éïBpðP@R$Ò!]T_ *mfib$²­e^t¬Þs<¦yôÿbw$}e‘4xlXò`	Òvoqñõ`‚y÷N”…ÙÒéü`:ñ_ÄÚùo çl’ôånIømoäYnãbâdeághjäm+jæéÿsî{$ë|z{íï~õö$Éxîj&ÿ÷_2!ávJçö	90y‘’)A
B:ÉpVODqSé`JXN9•PwçbYwõK¹ä
qcñðR€s1K™~¶›Xú‰ä-æèæÆ“@V@Ú81[B a;þ$&L<–ÿX«s€BH!£€Q€t¶MÛ Ð|p\®É_–º˜Á§ÞÏi™æè¿àÙáZÚß•,Í$¹•¬];×¿;Òkß:Æ¡Z#öc?úœyX~Ié>Ë—J1eš4‚ tH©˜î\ò¤ÿî=ñDçØŽ6éØÂ±ZÖ¶ÆàìÇ#ä±Ní€uðŸª“É¶îä,.ål?Q
6Ò´µíB9òèF^c¯±‡ØñßN§ŽuòãÉäÜâÓ=£ÕÍÇã+£}ç~¿®Þ×µOßñý:-ÛßNO¿ÝÖ·ïº?ÉÓÜšü5Ë¦ÜÕdv®Í¶ÝÖuË°þÉ­™úvm’ïßOjvŸ=GåÝI÷—òßï`N¥Üë#çš¬ìÝ)UêÔ¯íß	ë÷ôù÷Ÿ×r%FdÀ¨é´íÙH+Ëïçn½Tˆ+=øáN<{XRå‹RòÊ
©¦X#­îÁy’áØ `KöØ2èßÖI–ðv'vºvSSDD==65.Š¬ÈŠ¬È—0,ËÌŒ+ÊÿÏü-,Ë*ÊBqÈÇõöÜþáNàððþô±”ùä‰è‡Hj§‡ÙÁ"­±€˜Ó·±¼´ÌT^ÜŠ	á¾ñs±Û p %Ùî”¬I’¤ãþš÷íãåÿãNp¡éþ-vþíåt—ýðí”ÄMî”Vöþð§ÿŸþÏøîØãÜ¬/òê€wÌ¬=ðçB%ìåþðÁƒ'