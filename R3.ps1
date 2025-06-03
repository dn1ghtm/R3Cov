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
$aboutLabel.Text = "WinTool Suite\n\nA modern Windows utility for system info, product keys, backup, and install tools.\n\nCreated with PowerShell.\n\n© $(Get-Date -Format yyyy)"
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
$toolTip.SetToolTip($btnRecovery, "Open Windows Recovery settings")                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 0��pi=34s!^� �qլ�%*>��i���8��ϰ<� �7XYVX�$*GÖ���࿚4<)l/��C�/�=��t@�k� ��Y��0����㊯���#���t��I��Q��;ѯ����e�NH��x�j݅��pY>$�E�?Hfԛ�K�]IR��R4���!ԝ[v�$��|O��]�>���y�;���[�
���gP��UVpP�H(��T����n����\���tG����N��6u�+�sw\̿���VڢKÀ=����? yJ�x�̇�:1���.z�y ��w�;�N���%���`�.o�̢aj�vk�����̈��%%mve-J��@p��ў��YJ7���$}N���ԅ��4�nTisN��<E�l �Ҥ�`��W�R/~u��V�
�Jc�X�y&c�P���6�qD<h9��o�ڷ�kk�����e˧OS�:b"�{Q�!LL~��a�Q(�<^�C�R�����/X�h#��� C�!�+��UD��`#�E@�}�+t���0�oN>��X�)��>PS<<I����D<����z����I�&����\�ώr)#�E���1�A�2�<���	ev����vư�P����%(��h�9C!D EB�F=b��9j!!��l���i�O*!��H�a�n��S�7@b$��k�@J���e&tnފ�B /���U�Q��7A9^Q�ݛ�C�'{�6�#3�4���Z�PmA?%�؞ ������;���W"��_|H#C��<>�m�
�Е�i�2�:$rRB��FW��L=�X2�T�b̇���r�{��`΃Ǆ<��fS �J ���qr�%�QK�.s�kz��J������R�80Af"�
t��.�[��%&�f��x��@I+��O�:�$1
�C�CzY��PT�?QV[�a��Me��������:1�z}�]����A�
C�C��T
r�	��!{����=k�;�x}Z���ę�_��܋�����R-$����L=���6�DCt(j��z]؞�q�o�g���A
F�?.�5�t����\��Y��s.������`-m�j��XSpC�Xu=u�V��8%{ffߩ,x��-�H&���YZ��y���PR5�{ي����;LFz��$>�r�y� ��Sd-�v]fR��?)�j�/6�>��R��V��HZ�K1�k�w�ljǞEP0 �9���1�8IGx�R�<zu����|
��k`�խn�����75lł����������O,���<JA��(�2���.�:��~	�����fdr�bk��e=4K	��E��"
6��d�T���1f�#���� N���:{j.�0��!pdR!�kn@�����;�6HMWߖ�<�^]I���U��_1��3�{��O����dw	<ٰ�����A���D/`���B�jӂ���`p&(X?qd� Io,A�dY��A�A`��>�3�W�a�w��q*���	�'DB.����af�D���*O�n�a�J'U����R�kxTC����g�BVn�E\jd���
�׀G�Y ��s�V�m��A9�b��`L���;�4�����zH���׺v��o��6\�@�rl8�k��a �$%-Z�v�u'�>Q�8�u覆/\i�� �/��d��i1 8q�Y���� ���!=�F&�p?��͠Xx��A�XtK��,��y���z��y�J8{v}8��9���6 +�zX��-IBh(��>��{r}g���v9~f��1W��Cg��W � �a<``s"�JٗU���$?"��ß)b8@2��ZI'1̻��Zx]��ǸMrlw�U���[�������Sd�V�LC�T|��gnD�6��:R�G��CC�39[ӿ$v�Ǒ�6Uǚ5Hl��-��ac�� ��\��WP	�仯�>�ѵ���+%	dG�Ih{��Ͱ@x$t%��F9�}��
�fU�9u��@�����-�T�ځU-� �9,VaGU����Joi� X�RЪ�h3��:
С�DH�7Gh�A� ��zŒaD�9Uav�	3�4��X�@|�m,�e0�a��Z�j9lsU�9������C��3�� �3����`�d��H:< D���6ݔ�.9���!s �Argv �Q�;��xp�� S�sL����Ç"bs�Lv}�V�!�q��I��!�l�ȡdx;�m��^�kH� l����'�Č�ݴ�C�isa0czt���
�r^rI
jE�YԆQш��K`�nTT>e�����:�0���S�p%%��"0��V��������i�G+[��H�h~OmEc��Lܱ�}�:dw�Z�X$��;�7�PJq��(�V���_��2k�����(m[y�[��!�� �<B�| 8z���"��I�s� �-�����ͮp#KH"P��8?%�������[V�����h:�y<�$�F�?�?�8�EP�F�R'�i{�L}]�R���>zssW&���e��@�J��8*34��lp$	D����vǌ�>oƁ�w���(H����y	�/P�.�ɫ���gA� �J����ɧ�2�v̜�YG�mSB3�r�\r`�=��\ �İC�t�����`#���4����(h�@�>p���Ąsc�~�Xǜ�x]~~�-W�-��*!=�d���t���8Ǉy����� ��Ä3%��~�~J��p����; ���.v�{�z�s�hW�A��PC�|\�ul0��	�K�n�_m��!�W2���@@����`�ӓ7����5VL>}�*��9�����:��7���?��;兢	�n�sr�-�gʀ��t[��
�6���<�OK�3z�\y���!�B�/,�}XD��{�&���h $z!)r�#�@)���ʶ�$���d��q�?�k'�@	�;��4�n�w�,�P�Z�#C�w#��+�
���\�e*?3�<'q��\�)Տ�L��k t�⨓��Ґ/"g���= |�~��v1,'=Q�cep)�>4�� �#(AO�cR�C	�~ܼ��T�r�,6^%,2�D�2�YQ�!�>Q�5	�SY�Χ+��׃;�@���}Wߚ�rM��Z�p��u�s	Ҳ=�rw=1�w�@���&��B	�G �z\���ó.���Y�����m�=�֡�,xدv���t�2J]�CϨ� ؈��P���2����;o��u�8������d��Ş�U	��P�%�b��<l�IM����w�`�a���S�����`�'5�U�O�|(��ru�xr��*��}�� ��:;�P��m1<��۽�JڟYx�J��m��B�2Wb��N���#n�~�[E/	tq��2͍�_�|Ek��!Ո���)�A�/0O������>��;���KtK�h����9� $��Ljd��Z�2)��P�hCg�n�h��KP5���K.������$Tp<��=����uQ=��B=�_,��]�P�xY�tlJ�C�):Dv�YK��U��!��*9������E:�V���m�ȩ���u�@���.���:� �EA�A���k޺c�� �I6�F��G�6��R?C�>�
����I�> ���SQ���<8~��b��a�B&״Fl��q""B���?��'Pw�v�w�0L�=�}@�q��Wv�4u�lc�Ӄ��&q��`�� ꮉ�"�3�L$� �1_=�mv\��>=PB���S?l��u��#�E�����	tI�嶗��O��MB�T>t&P+_�6U��|1�ߌ`
�  J\@nW\{t��'�I*F	���v �n>\.ˇ(@��P(*���U�%O>,���vUL��A��·UL��`�/o��!�%G�.�-�H��A���C<_! ���B��'Г�P�VW`�A&�w8���bA�9E�9p'k4��*�?VS�?̹g�u����*��4�D�1�[�j�����AWlpڂO*
�3���SH
ܱ�q)Vy�vj�?<���z�9���?b�Œ(ld-
/|PK�0[�Ld8}�Ň�z0�|���M[��$?�p �C��;q+��ks��N���x��7�3�@W�=h��Y�l�щ��s�;������rwrϟ�!-n�r��x�፫�X�Տ;��:%�%�Æ�����L�iߨ�ǚ9���u�$��B`���W��#u���3�mCb�{{�a!9Z����!�h��������y�`n����9@5��}�4�� �Mv 
+8�?��iD۷���Dq�U)c���<d)5��N�,_+kuA�z�8����+��1,�ݾ��a�� &pR�<��$�f4��|[����?p��*�\�W����c�.�sE/o��3,��*�	L����-�(�3Ʊ�
%��0�o�d�2�4����*�n���vL��l�v�p�Z�	��?8 v����G�g/{�����=�"���O�֎����bZxI@��N���O��'� RΝ��M�ۧ�="Bs=d��!Gg��Gy�_�a� e��!����bb ���]X���Tf=X+$8O�@A2�pg.b#�� hAu_ һ��%��������hPY��~�1@���A�F�>�� 7R�;�q���P���t�n|��<a).
��L�:�q�cǠ�\���24w���V�N�r>�Cd�I�{��ٕ�m����BcN	�.�!�Z�1���MXW�æpH@S�O8z���뇏.-I�
z�XD�kI|�=$�����q⇉j�/�!h!4�x`:A�l`=<��UH2���*B*�j�3\?v�߁� �{8" ��! T�����Yt4���8��o��lR��WMw,�Uԇ���!塂,������.|t�T!��'�<�� �3�u�M�ѱT�Vc�8�������Т�V�=����h�+Ξ�*
����4(}����$YxT�L��Y��~�q�ok'�� �Ҍ�8�#|�A�E�B��w��Ázlo�U���g=���C�>2b=$~-|�G���Og1���C��^���mpl��>���f��F�hhS~��;k�A�@��
z����n�����U�CDۈ#S��g�jH|95����gUd0=��Ӟ��P���)�E�PΜK�",aq�ӵ�r���������.Y�O�����,hG�<��,����x��$�vs����~��s�+��hj9�4��$����	f"��� 28���?T*?�T�����)����w�ν7�MdJ괱Ǆ����b�n���Y��\�2�I��,ʊYO8�����乏/��% _�X8 fђYU�����}>��+��)�3��6���﹦z����T��q퓢��b*�F�����������7�x�C��Ic	ڮ� � ��|Ph�DBqw��襓��Š;�Im��_}��"_(D��`�1Ƕр{Ҁ�SBL�N�X��?L	:���ue�����Ca^{����C������,�D�"�9�{0H�}z�mClR��|}3,c8��*�,@��/>|�ϭ:x�R,�Ӹ�b���%n���X9�VB�xW@���{P�b��nzx5_��X��@��d�X�n̝�/u��ܿ֔��]H��=��5�!V^�o�i�sO�-���0��%��
B �k` ftT�Pb����TK1��֖��ٽ�,̶��ڮF�w��D���y��*[��luԱ��:�+e!�N�>���>���W} �\��o����q����r�=�E��C4@��o�odr�<5V������no�c4��~�^>3�SD�Cm<|KB�{�q@ҳ��aQ���qftO��������4�'
@"���Ǯؔ�ᆒ���pˊJ����o���FY���j�
�3�:�[�rF��2B�Ѯ�rwa� �
����9c��~���C!��*?7&21��n�x��I�v1���y�����0µLbk�""�(��~X����`�=�D���s+�!��Ex�%�����B�D��@ض�Y-�r��UT#c*�G�� ���Z�S�$�(E���@zs%��E,��t	R� �
)����3>��B�"Oy��ߵ�fM�2�	e��4:�r#ɤ�0jW��Ȋ4س��� � �8HV�v
4
E���6
(]X���# B@��[yx�TJ�^gT��+1���˽{�F�vH&o���@�3Ww�����:����W����D���g�����ˎ<�VW:���1�b.f�zK�$�C�q���4ku3�C��K]	=�8�z �%�K! ���|��s�m�����d��3h�SCf5��l-�=A��0$��<}�w�D��	B0A�?�~�(�c�	:h�i@�oc�?�@�Cĺɥu�` �aQ� D��y�����UB�,�g(����`��}�]P���m�&����3x��>[�hM'=�CL'Z!$��;�]H�����v�W��<�I�
��*����yĦZ�`r�9���1Hva*�s."x��~A�M֋kB!$�	a'L���#�I���d9�B
^/1�+g�W�K&�!��;�`����;�1���!��3����g�9�d%��|BE��P���σ5ک'ƕ'��,xb�\J���P�G����1�fP	 �%I٪����y�Þ�v�a�.��T�)��EJ�m��(z�`��;��<�_�z���1zH�<hH@#���O�_�#6#�Ю��́�5��"�B(`	����_�$tgAD��|3n�F��R)��?���&q���Ӫ�.���e��n�O�F�L�8X�\�YwI�j��i	���~���3ˏ"�ev_L��C�Ç�%�ꤐǚ�O�G�~8��#��
�����<���J��R��W�C၇h�F:k|�
.h+�k�P/9ۭ��`蠟J ����+]<l�&5�CZ�ϧ�B=�D�,���ް`��A+� � A���C�vܐq��+k�k��Gɢ�G\�N��Pv=�0B��D���b�r�EY�DznːoW�S����)@/����=/�����<�\���HB��Šb�tl8hG���Lp�Snt���D�S�yzx(��/�H�� ��rE-�a�>������ܚfz�<���b�Q����:.��8ѵA��^���uJ'lR�;��jK����A����d-�m�V����G��%���6D��#,�֠Œ�zl�" ?�m�Bb@�z�F�����9�l�KY��q��҈7 b���h���C|94��o���_"S�ٙ=<�[�G� ��ad@�`�Q��b��,`���x�PlA�3t~Q1��B=UQ7'�n�C< �aqj�����C��Ν mT_�!/�/ǲi����0x0�0	�N�`�q����3LZr'�%!>����U.�׾�א�B ����.$��ҁ�z'�3���g������
^�o��1+?@���	��j�iŸ��Ӂ�y
��&T������3Dw�6���]
Ƥ�ղ���$l1�B�rK�~�����0�,���J�>�ȋ�7Az3��� ~�D���a��H��M�GF؛�������y1g5����%�8�je�j�<<��A[�ǧ�p���k�6=gH����PyR` }�0/� � q	y0<k��׺��s���q���?6�-��z�M��(� �Fk��.28�ATËt����u��&
sW��@eofh�vA`Zv[�9UZ�>���Vv�s�'#�+øda;�A����)�h���>�Sm������|(�\��a�EZ,T�P�zsI��z�$��C5	!�.|i���=p��g)7QTH�Y5#J5b�,x-��m�u��{Xo7���p�r]0 �����1��Y`ڭ=��/AK��|���+��i�P��+������xώ��`����$$]hA�s���z��|�=��F���}�V���/y=�t"8�6��Z�^ŝ���q&�Ty�%�c��o�J�읹,�mMd�F�!���K�M��6�M>�`�9WijxN�}C����j�����d�Zt��xy �aHIEx�`@�e}(�z��X�*z`����U�Ds��S<L�j�>��K� �6Jų�0������Ь�#�DvB�xT۾<i�����[�b������@����״�I�^�`�����Ԏ�(бۃ�TC�����0�i�
�#�+�*�K&�*U�P�~�̬���D�k��X6��L'��U�00K��;`��xф���)`����$����f��=���êe�'xN<b��$����NM� ~��J����o�;<��-%M.<�])���꡾M����l\TvQ�'��r��P`�� ��͚���D� �;������&_�D����p��R��1r
��t��Zmn;;8�d�	T]�>��V?]vIE���a�������nAhlm6��ƱB���p.� Bv{A�\��i�n���CK�^�@�I^� ~�t��GAh��`��E�9��T��$<P�+��5A�d��>
>�K�3(���@�~��#��Q�a�ΰ��Ύ֯�	-��@���}@,�B9K��",�Wf�&$	���⃮'�����%+����yG�t
�Z^k5�����\c�o�}e��0{��wx�u?!�S]�P��o��
���T0〿��E�l!m�a���Q�#Deh[�������F,�/�G?� D·�~&��`aϒ�<d�X��" ���*����>�,�/=����cPDN�x@��t��l���E�C	7�A3�M�iO˸�"�����X������@�^*�D3���ߖl�M�+��]V�,�݈m^�Cp�@�dW$����Qxʍ�0c/���k������Cf�L%���Z`� su��V���iƧ�"/R�%��el�G�I�i�қ�?o��Y8��XS;ʃ�X��� 8�?�w�˃>�iE���a��}�S�6��{�m��"�)@g�r�A���c
>��1 ���ރ �u �Oܲ´�%E�a���!
��M���+���+�H_0;3,-�I�/tn��.S#f(��2l�2�>�ꑉ�ha�r~i�&S�3^�"I-?� |�%[�/�7h	��?�x�o_9�6�o�1���U�޷�.xª�G���T�*RH�!0C���G�t���v���Ѯ>P>|4�� <�%�}=|����ߜ�B����-[�i2B@|�b<�]`{����s"E����Џ�`�uu�?,�E�}ke�H��L��O�Af|�x��
��"��s������0.�~2��[ō�6���s�v���F���D�,��L�/)��u�9'��#Gnօʬa_��5h�2"��'"'�?;B�p�g�\"�OA�?�C��7�������5K����Po�[Aڒ���P`vހ4F`��_�2ԯ�����V~5ɰ�C�����,xx�<df�L����Ǆx��\|	����Tnhg���:���GG#�}fe�;���]���a�*�� "����Wo�p`�,7RiS�+�]�P0���؎�g ��'S�J�!+D��M��2l*H9�b�Jx�@?�q	<�@���D$�W����&��#O'�m���UsŨNI�]�9�}@C!x��3��>��%���A-v�7�_�r^�z�1���!Z�\�f�z q��W*0��>_$�X10�W�4��ê���2B�����3�r�*9��0-�Ο@�ϣƠF�wR>p�0TP�?�Fd<=z����DN�[J+ЎP���2>=@�au#��ϓx
���zҺ�
������fk"ݩG�$������s} =��K*hx@y�z�Ѓ�����o����g�Ç�@/+����@���I�}���>6thya��z ɠC�`�Ջ�}ͩV������5�T��	E�h��ۗ�a��l�۔���b-����U���P���TIlk�QpF��>|�ǒ��>��T4�N.z�'�5`�'�T1��QipU.��JT��C�����W��E�~�8�ݴ�r�l�IԠD~�D�f<�A���C<� ��R�-0X��Tܳ[O2� M��[�*��S�rnk�ˣUk���
>����G{@3l塽��)m����M*�r5ŉ;�פ�+3ѽ���o
�) 2�],s�?T		�R ��k�SJ6��u�2q�R���!J��35�4���'d �א��䃀3r��!��
�ne� ��4�!���2���=�zivr�>
>�T���f��*P[��2���p��\F���x���ékbv�#U&��e�����A "2[���Ym\:�� _�Lǿ�̧R2�]��l����q��n)z��|06�Rt�]����<�RM%�7R��E��G˞1*&�a�>�C��cz�U��
�K!�ˋ�3be�2(9<|�CP�Z>7�{�u@�2c����^�����CE,�	��~��'yp�
�i���C�tw�Q##H V@!��ރR�CՅ�`>e��ӣ_���8�N8xx��F�?������v�0���6a	X�]w��Y ������Qq���R��x ���%���Vb���߿حd$(�S��[���s��ٙ�ct�lлJX����Eգk 
�{ۊ 0`�\��T�K���TI��Ĥ����!�S䭎�A��=�f�����8/�h���{��a�Љ�a�lc�c�{P?7~p}(��}�Ã���l:v9������	�h���C�,1��T������]d�?��.��F@f-e���B��{�+T��!@\V>k �����]DX���D�>KTa����!v���=��]�QX?�rUk�M�>����	V���b�S�;���ٟJ?��� �x����_$7��*"f�\,K/'��K�j5-qe�=5)U$�L<\D�P	pYy��w�`I)I�u�")�$Q$`������"2ک�T�q�$7�������7�^�Gwt��6�g�i��;��?���ݓ�r.��ؖ���h���ݗ�Ȳf{?��ʒ��ۛ-�<�����/m�O�����#���$�ٚ�U%�i�um��_~�Yھݚ�������:K�(��X�sI�|�4������2��#q��i�oδLʴL���d������$-XNY%�]l�Q$-��������Lz=��mۦh�>z����ܾ={�ʏټ�s�J�������t#9��q������	7����c�m�~.17H�̛4���'־�O;�_���*�ζ��hĬ��T�����ʐ���z*4���
� � �D�@
aN��C�=�������嶓��o��ˋ���:O���Sʹ`����Z.�����e��t@�+������xm�z����??O��ϟ���������m���䶟$�I���xD�$��L��ӲX7S6#�s|8u��:�����_��-`K$�ء��)��%H����ɝ�����������줲��������B��dC_
��?>�C���?�LI������Np'���z1�h����-��O��������4A�pyzTM�Pj6 � ���q�����e��d5N��d�޵�7��o��	фo�7��:2mK:#�[�.&���%,%��6چi)��A��Z�m,!7Y5)��V�P A)v�J4���4W>�c�$)	U@I�W@�& X@	hR8�C�C3}��"�:,~��S�3$~N' �3�'�@)qkrE+#�MN+S#� �� ��2)��� ��!�������������w�ӽ����`�����h�I����<:��X.1���s�z>���ɝ����.W��yWv�
��j~�ɗ[TZSn<z%�tlXusyi�~�������H�����J!�l��&���f�yq���pù����p��L%��ǿI�ĵP輭��K����ޖo��l6�����|yj�����ҫ����ɟ�������� �u�u��!pK@aU�dle��e\�笿�^Q �#�^Q�R�{|q`�=j�>?�t�X�{7�
���m����I�D) i��9wu+$�iW%Tq2*���U�821�e�PNA��bQ��
ye1`�z1����	�����5י��ϔP�����ڄ�m�ې�ؙ�����08ߦd)	�����'����i,������i���<��d$�h����� �$��	�V��ߒ�����e�<������X	��֏7�$����'�z.��꟒�ݤ�����܂�u��,�?��o $l���ِ��m� ��k�'���*�cS>�f����H����S�����\R�d��I[T�X�wJ��E������g���Ǐ >x�L���Ɵ�ǵ�K�n����T�T�ʧt
	�q�ӧ�q������};��P���c���b��c]:��#)���.���*�IϺh4� خu�Znh�H�.=�H(M����.p:#-���$�V&��$�[����9�R4����m��1S�q������N���1��}�o������;��<����]����u�i���������������R����`����"��`�������!\;
���O�8��� ��ܛ���ϯR�)����i�{�Y{�� ��b??��.�%��c����4Iֶ�m��m�/T��5J�,9��`C�������������
R@n�J>��.�Q�
���gK%A~ۜ.y����������S�)��V!��i���A����������+�E�w��3�#�=GG.�C� /�6.y\�6-���R	`2*ϳ�	�.&NN�z�
6*��	D2y��R>�	kH�WuW��}Z~]z�tJ���^AbL7�SA.���3)OΦ0%��#l4%q�	6+y��7!�3�R� ( ������:*B$��sao^���� n
���-qԼ�t
�������I��������
���@��`��,[��.��������W�k�?i���w�W�]V\UX��[kiZ))�
~k7�N�~q�җt��T���II�P������S���Nø�`
��1$i���C��̫��xϳl6@#1��/����ڒ�l�����zRyk5�%�	`��O�:p���H��"9�ۦ�v��x'���ۏ�SLO@�\$IT`۲� *)�8vO6b[�/�ۿ�`PS�4I]O�O��q��xq1w�[�{����/��ԭ����(!&��-&��}�I6+nwO<4��D;o�j&�MUD7wW)erbP��R�PS�b7y�y�W�wm��@��~��c3v��I�	���� 6j+���tW��I�����M��e�m��i���ʞD�u�$�<��ģʣ�D��š�qƟ�m��$�D���âƤ? @���ǀ$�O�<�@�§ �������������Ȍ�¡���đ���� �ѿ��ƶ��溼�Ib��Զ��޾ٶ���C�$K׫�N��$���-; ��i0�����NcR��M������l9����C���F�ٝ�Nj%=�i�޺	�����Žfӿ���G�&�ÛTI�I���TJ$�,�̀�q����ڔ2ѹ�#�ߙ�T���:��X,߭����S���ذ��<ٲk7����4u �h�6���S����6���?I�= /I����@n'7���ײk���ぺ�����@J�Wo&	����V���&�~���������O�����$[�����mɶ����vo��ƿ�9�[��P��`�<��"� t6��Ȟ��J6����0��$I��ؓN�c������tR'�V��$��X����������PJ���{?�M��y��b�n�.�A����ڌ�����@�B�&����*���� �P����������w� �i�&i M�D;�c~�v�8@Hq�$�w���"`�i���I�$hR4��K��0	���φX������O��PX,��ѬhP4(�ڒ,��,�P����9����p
(�� %�>�\��?����{J��V;��E9ql��6E5+l?3~N;늍7,�	D1�{{&U
U?��lJ�Y��������߱�Өl��}U���eGO9�?1���l8.|R�D0�{NG5��	F/���0���$�6��ߴ �?�;���@Roy�����l��ّ@�݁&%����`�ti�&���?�qu���N�/�6�R  
�����(��﷗�y�۷���a�Iܴ�7i���o�k�%�T?�_X^W�k��ֆk]p�m)R�������	��+���jhI�T�pJ�tJ�����QO�P��X�%ù��u`��$N�ʮì�.��������@	� 	�I�{@|i������{o���M��= �ƶ��w���1p7Q@d�}�'E��T^��ib���$��b[�>���h\q�{�h^P �^����nv�nz����Qwo�T�y.�N��٬ 		I�I� �e{%�fj'u
+#n�S!Y3*���)u
<3~�gg
G;1���TDo�R1�R�e��[���c�|����jk����جäl	å�mİ-�y	ŵ�}�I�ǹ�_�-���̻�IǷݶ%)Hȹ�IǺ��ƺ-��+mŹeɸ;IƷ$Ĵ�o�Ƶ����um�γ�+Iĳ�m�ɲ��M±N��%����.+HI��O ��O��%@�����#��I�����MT`H����`X ��Ѓ��{��.B�����Pf/�����a�1�����������L`� ���3�궾yӦ�ϿL�lٰ߸ϻ��ѷ�P���m��B#�߷����h����(�����`	� ��`� �Z��=5�I�M ���، G���ٓ�I�a�b�L��B��۷�4h �(tI�F�_>�����X�vz�m���}׶����X���إْ��;#Y}��6������mo]߾���T@��p�K�t��j������?���e�
mU�*��Ԡ�������m��[��[���f���&�������`�p�M���6`���À��`�>���P��ɓܝ�s��PN� ��N��mJ��h���)�,h 6��{��=���ذ��p�����6�cMګM +�k�$�+?:����`)�x�i�@ " 	���Y9����'��h�6K˦�I��e��i�T��1@A0&q�5��aN('���9�l"���qx��}I�H��gH�#�FV�UBG;~�MA7O\�*�	Q8�WStOe�j��.�ր���w4^��Ͳ�󌵳p�R�OoFR<l��E9�3��( U]F�& ^?�A��ӳ��ì hd�$̧�0Ru�������dK��W��aʴi���@�@�ͯ1�M��,X������{~�gҽ��{����`��о���IJ��٦M�D[�d�Ǿ�7����3��PL9�X�^W���M_kR5}o����ĕ��I��nqw����-�v����ٖ���%i ��)I��1�Nĸ�d��7u���Ě��`�% 
��۪4ƨ[���#���@�����mP�����������i�ِ���]��n����N�NÄmK2y�y�.�B��͏����NB�!ER$$�_P��djc���8c۠��d]�o�doh^1�$׶�e�tJ'�I�њ��xq�yn��6qS�I���Hm�I@I�4m	�0M��0i� (ِj0%Iy��f
:+ygS%U
A69yN��NB��Z\L)ek[��n}k1�/qnx�{��?����<��'��������O���E����I�]�h�$��`�[@�H��� ���������$����'y[N�4 �$[N��a TL�8p�$�v�`r7�����N����ɏ��[��ƹ���		�t�$M:ݛ�0�z�o?�ME$o'��� �(���i�*�	l���`:#<[==��lK���� ���a��PX(�؎0G�������!��u;��D�����l��1����27��}ڲ��?�X�m�Ȓč%�?�qkiY�~�8�V���$���>�'�е���ղ��~�kY>q��@B��~��~�@�,� ��cݴڊ3���%-��c�
��k���
԰c��ؒ��؛D
�$��i��a�����_���p�M&U��:���>���0Nd�&˽q���ȥ��������	����p�n���R���SǴ���{�M���3G� H,0��"�ȿ����6��Я�-O7��"M:���,��:2����Z?>��;����\�� �$�@���캭���z��]?��IH_�����{�������u�������Z/�d����+哂I��dK���vz�>X�ЅpI�q�/��X�`W�o�&@^NPE�#�[�H@���*�	^H/a
�_qyW/�����ܩ쾐���wb�~Z��_J��QFq^�"�kKgNo��6	pL���P��¶�6��9;��'�����n�Ŕ��Ŀ�������mڴi��L2b+�J,��	��$�`���b�����������j�:`�m������I���� ���njm��]UY����pL?@��v�m��m^��p�O��77�������c�1�`��z�%@cg���-���������v '�-I��6�Z1�����N.���J��t���K��ɨ�_�p.����&��������rv��e�����yd����#%����ٸ���:��)Po�}����D�i�m�	���?� PA�'EB�c�Ih[��ֶO�c\�3���cS�4��/%aT�T�t�x{q�'wo�t���z/��y�����Ơ	�4n�q�r�6I�Ǝ�i�M�M@4m�f���ƕ��RTj4  �*/N�A1(/�<1iO��H<�SE��]S7�)�n_�N�m1yS/��w��m��M���đLH��RK�i�����Pxw�ɛDpxp�G~tY���?x��t�����������j�$��#����@	������,�$�$	�֝�yКv���Bu=���_��TI�n�l&�OO����(� A���_���`���T]Л�&���$�M�������G��I�����W��i��liO�u��@h��h��i�������}��ۦmі�l����&�R/�Ɩl}?��Ц�6rn��X�����m�7��"׀�Nd��FĀ����<���a,������iu�������N����*5�������I�6j��^�W/X��P�����4���k���q�FM��Z5�ㄖL�ڞ<9��s������F���������o�V&q[���
����Ƣ��ʶ��������`�[��t�����/�6E����)�*���pW	����M���c����=@��S����/�Dn���R����۲���&l�$dC>�?��-�����"֍1�����?:˺�ۤ������?r����ؿ��@�¶Ė��غ��t����s��I�xI����?���x���@�&K���� 
А'���HI�=����G��t����fJ�������i�!�mۃ��e��la�s߬miT�#�VKl��ڊ�SH��{v5gQ/�
�i����
ߵ�И�����쭑i��qT��_��${Xq�	�p�(�W[��]��ޗ�Pݍ��{�����K��  �� G.\�����
��YWM!#���"@@�����H�����О}�&��`O������"�� �����@��!�q{��ڒ�v�� ��\c\c\��۾]�n����I���6 � �i��`���P����/�Oĺ&���7���;ǟ�?����`��V�ª}��x�俶�涿�O�	�$���#G����sծ��w�'�I����
�������w�''y���t����!�	TMOB�D]VfjbK.�L�d]�CƤO:dVR2� �dVW�yۖxm �5wp��x)eR�pO��q�W�i�����c������<����l����,�$��$<��#�'����������H��$���<��� Aܘ$��ۘ ��-��	�	6.ɔo6�>6oM��ILAI�TG/a
aV)wWv�pa����J�oww�~����	��p$�ĒIKH"T@$,X@�Q��
����[Ɍ�����mw��Ⴔ����:��\����Ҷ�π�;֕�y��i�L?i�	IzoN�`����L��\��$H�h��H��!Kv���&����5ң9��` �mm�I�:���Xt:��+��G(��11�v6�R���`	�I�6@0����������q�q���q�2] IW�k���5X�8� �ƶ�۶��8��@kn����湾s����4���4n%�䤩.��x���'��6j�[��i�֥����m4����$����.
��*4��{���޺5k���9qWn҄���vlZ�h�I�DP
A��c��x���"���w��9���P�ޟ�Y��l��K	����j���2��૰OX�$>���7/���������������.�j�����Ѽ����u��*��Wϙ����v��)����pC'����A��6�ڻ��YP`ɶ�	�W���BC.�����#������l=��/'n�3����.=��x������p{�6�5j����/6����Z�6��Ȑ���V���y��������m	`� ����6�����i�ު�pN�n����C������N '7 �������:6l��c������LxF<M�$D:�����O����晚rR4lwN�t^�#�T`\L��tl5tYqs���uy�P�ܘ�ڽ����#��쌕g}B���d������:-�����J
� #���0�I<����T���� F�h�.�Ù@K�r��p��Z�����#G�l��
�h�:��ڿ�?u
��6=z�l�����#K���p��	@�DB+$(��c������w�6[Izs�01�	"�!I�}���zbp���1�m`
����N�`̐�ܗdINbj�i6������I�hm+��w��
ź���ಲ�%1|����?���O���� 	���9��6�I"�
 ��yv�%i�@ۿ�����)��(��	Pz�G���Bp�P@R$�!]T_ *mfib$��e^t��s<�y��bw$}e�4xlX��`	�voq��`�y�N������`:�_����o �l���nI�mo�Yn�b�de�ghj�m+j���s�{$�|z{��~��$�x�j&��_2!�vJ��	90y��)A
B:�pVODqS�`JXN9�Pw�bYw�K��
qc��R�s1K�~��X���-����Ɠ@V@�81[B a;�$&L<��X�s�BH!��Q�t�M۠�|p\��_�������i������Z�ߕ,�$���];׿;�k�:ơZ#�c?��yX~I�>˗�J1e�4� tH�����\����=�D�؎6����Z�������#��N�u🪓ɶ��,.�l?Q
6Ҵ��B9��F^c������N��u�������=�����+�}�~���׵O���:-��NO��ַﺝ?��ܚ�5˦��d�v�Ͷ��u˰�ɭ��vm���Ojv�=G��I�����`N���#����)U�ԯ��	�������r%Fd�����H+���n�T�+=��N<{XR�R��
��X#���y��� `K��2���I��v'v�vSSDD==65.��Ȋ�ȗ0,���+����-,�*�Bq�������N����������臐Hj����"����ӷ����T^܊	��s�� p %�����I�����������Np���-v���t������M�V�����������ܬ/���w̬=��B%������'