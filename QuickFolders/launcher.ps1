Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Avoid multiple instances



$mutexName = "Global\FolderAutomatorUniqueMutexName"
$createdNew = $false

$global:appMutex = New-Object System.Threading.Mutex($true, $mutexName, [ref]$createdNew)

if (-not $createdNew) {
    # Create Modern UI Dialog Form
    $msgForm = New-Object System.Windows.Forms.Form
    $msgForm.Size = New-Object System.Drawing.Size(360, 140)
    $msgForm.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $msgForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $msgForm.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30) # Modern dark theme
    $msgForm.TopMost = $true
    $msgForm.ShowInTaskbar = $false

    # Container panel for a subtle thin border
    $msgBorder = New-Object System.Windows.Forms.Panel
    $msgBorder.Dock = [System.Windows.Forms.DockStyle]::Fill
    $msgBorder.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $msgForm.Controls.Add($msgBorder)

    # Header / Title
    $msgTitle = New-Object System.Windows.Forms.Label
    $msgTitle.Text = "Application Running"
    $msgTitle.ForeColor = [System.Drawing.Color]::FromArgb(0, 120, 215) # Modern Windows Blue
    $msgTitle.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $msgTitle.Size = New-Object System.Drawing.Size(340, 25)
    $msgTitle.Location = New-Object System.Drawing.Point(10, 15)
    $msgTitle.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $msgBorder.Controls.Add($msgTitle)

    # Body Text
    $msgText = New-Object System.Windows.Forms.Label
    $msgText.Text = "Folder Automator is already running."
    $msgText.ForeColor = [System.Drawing.Color]::White
    $msgText.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $msgText.Size = New-Object System.Drawing.Size(340, 45)
    $msgText.Location = New-Object System.Drawing.Point(10, 45)
    $msgBorder.Controls.Add($msgText)

    # Modern Flat OK Button
    $btnOk = New-Object System.Windows.Forms.Button
    $btnOk.Text = "OK"
    $btnOk.ForeColor = [System.Drawing.Color]::White
    $btnOk.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $btnOk.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnOk.FlatAppearance.BorderSize = 0
    $btnOk. Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $btnOk.Size = New-Object System.Drawing.Size(75, 28)
    $btnOk.Location = New-Object System.Drawing.Point(265, 95)

    # Hover effect animation for the button
    $btnOk.Add_MouseEnter({ $btnOk.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 65) })
    $btnOk.Add_MouseLeave({ $btnOk.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48) })
    $btnOk.Add_Click({ $msgForm.Close() })
    $msgBorder.Controls.Add($btnOk)

    # Accept entering "Enter" or "Space" to dismiss
    $msgForm.AcceptButton = $btnOk

    # Display window modally
    [void]$msgForm.ShowDialog()

    # Clean up and exit immediately
    $msgForm.Dispose()
    if ($global:appMutex) { $global:appMutex.Dispose() }
    Stop-Process -Id $PID
}
# -------------------

# 2. Resilient baseline path detection
$baseDir = $PSScriptRoot
if ([string]::IsNullOrEmpty($baseDir)) {
    $baseDir = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
}
if ([string]::IsNullOrEmpty($baseDir)) {
    $baseDir = Get-Location
}

# 3. MODULE: CONFIGURABLE LIGHTWEIGHT SPLASH / LOADING SCREEN

Function Show-LoadingScreen {
    $splashDurationMs = 1000

    $splash = New-Object System.Windows.Forms.Form
    $splash.Size = New-Object System.Drawing.Size(320, 100)
    $splash.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $splash.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $splash.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $splash. TopMost = $true
    $splash. ShowInTaskbar = $false

    $border = New-Object System.Windows.Forms.Panel
    $border.Dock = [System.Windows.Forms.DockStyle]::Fill
    $border.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $splash.Controls.Add($border)

    $label = New-Object System.Windows.Forms.Label
    $label. Text = "Starting Folder Automator..."
    $label.ForeColor = [System.Drawing.Color]::White
    $label.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $label.Size = New-Object System.Drawing.Size(300, 30)
    $label.Location = New-Object System.Drawing.Point(10, 20)
    $label. TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $border.Controls.Add($label)

    $subLabel = New-Object System.Windows.Forms.Label
    $subLabel.Text = "Initializing in system tray..."
    $subLabel.ForeColor = [System.Drawing.Color]::LightGray
    $subLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $subLabel.Size = New-Object System.Drawing.Size(300, 20)
    $subLabel.Location = New-Object System.Drawing.Point(10, 55)
    $subLabel. TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $border.Controls.Add($subLabel)

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = $splashDurationMs
    $timer.Add_Tick({
            $timer.Stop()
            $splash.Close()
            $splash.Dispose()
        })
    $timer.Start()
    $splash.ShowDialog()
}

#Trigger the loading screen immediately if instance check passes
Show-LoadingScreen

# Resolve file strings securely
$configPath = Join-Path $baseDir "config.ps1"
$uiPath = Join-Path $baseDir "ui.ps1"

# Pull code directly into memory
if (Test-Path $configPath) { . $configPath } else { Write-Warning "Missing config.ps1 at $configPath" }
if (Test-Path $uiPath) { .  $uiPath } else { Write-Warning "Missing ui.ps1 at $uiPath" }

#Execute UI loop via System Tray Icon
if (Get-Command Invoke-FolderUI -ErrorAction SilentlyContinue) {

    $global:mainFormInstance = $null

    $global:notificationIcon = New-Object System.Windows.Forms.NotifyIcon
    $global:notificationIcon. Icon = [System.Drawing.Icon]::ExtractAssociatedIcon((Get-Process -Id $PID).Path)
    $global:notificationIcon. Text = "Folder Automator"
    $global:notificationIcon. Visible = $true


    function Show-MainUI {
        if ($null -eq $global:mainFormInstance -or $global:mainFormInstance.IsDisposed) {
            Invoke-FolderUI | Out-Null
        }
        else {
            $global:mainFormInstance.ShowInTaskbar = $true
            $global:mainFormInstance.WindowState = [System.Windows.Forms.FormWindowState]::Normal
            $global:mainFormInstance.Show()
            $global:mainFormInstance.Activate()
        }
    }

    $contextMenu = New-Object System.Windows.Forms.ContextMenuStrip

    $openItem = New-Object System.Windows.Forms.ToolStripMenuItem("Open UI")
    $openItem.Add_Click({ Show-MainUI })
    $contextMenu.Items.Add($openItem) | Out-Null

    $exitItem = New-Object System.Windows.Forms.ToolStripMenuItem("Exit")
    $exitItem.Add_Click({
            $global:notificationIcon.Visible = $false
            $global:notificationIcon.Dispose()
            if ($null -ne $global:mainFormInstance) { $global:mainFormInstance.Close() }
            if ($global:appMutex) { $global:appMutex.ReleaseMutex(); $global:appMutex.Dispose() }
            [System.Windows.Forms.Application]::Exit()
            Stop-Process -Id $PID
        })
    $contextMenu.Items.Add($exitItem) | Out-Null

    $global:notificationIcon.ContextMenuStrip = $contextMenu

    $global:notificationIcon.Add_MouseClick({
            param($sender, $e)
            if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
                Show-MainUI
            }
        })

    [System.Windows.Forms.Application]::Run()

}
else {
    if ($global:appMutex) { $global:appMutex.ReleaseMutex(); $global:appMutex.Dispose() }
    [System.Windows.Forms.MessageBox]::Show("Error: ui.ps1 could not be loaded into memory. Check if the file is in the correct folder.", "Startup Failure")
}