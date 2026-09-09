Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Invoke-FolderUI {
    $bgColor = [System.Drawing.Color]::FromArgb(32, 32, 32)
    $btnColor = [System.Drawing.Color]::FromArgb(45, 45, 45)
    $btnHover = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $btnPressed = [System.Drawing.Color]::FromArgb(20, 20, 20)
    $textColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
    $accentColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
    $accentHover = [System.Drawing.Color]::FromArgb(0, 140, 240)
    $deleteColor = [System.Drawing.Color]::FromArgb(180, 40, 40)
    $deleteHover = [System.Drawing.Color]::FromArgb(220, 50, 50)
    $dimTextColor = [System.Drawing.Color]::FromArgb(150, 150, 150)

    $global:isDeleteMode = $false
    $windowWidth = 455
    $buttonWidth = 400
    $buttonHeight = 42
    $buttonMargin = 10
    $paddingTopBottom = 40
    $windowTitleBarHeight = 39

    # Setup Main Window Frame
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Quick Folders"; $form.BackColor = $bgColor; $form.StartPosition = "CenterScreen"
    $form.TopMost = $true; $form.FormBorderStyle = "FixedDialog"; $form.MaximizeBox = $false; $form.Opacity = 0.0

    # Place this inside your ui.ps1 script right after your Form is defined
    $Form.Add_Resize({
            # Check if the user clicked the minimize button
            if ($this.WindowState -eq [System.Windows.Forms.FormWindowState]::Minimized) {
                # Hide it from the taskbar completely
                $this.ShowInTaskbar = $false
                $this.Hide()
            }
        })

    # Master vertical column panel container
    $mainPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $mainPanel.Size = New-Object System.Drawing.Size(415, 2000)
    $mainPanel.FlowDirection = "TopDown"; $mainPanel.WrapContents = $false
    $mainPanel.BackColor = $bgColor; $mainPanel.Padding = New-Object System.Windows.Forms.Padding(20, 20, 20, 20)
    $form.Controls.Add($mainPanel)

    # Sub-panel grid array for directory row buttons
    $listPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $listPanel.FlowDirection = "TopDown"; $listPanel.WrapContents = $false; $listPanel.AutoSize = $true
    $mainPanel.Controls.Add($listPanel)

    $global:folderButtonsList = New-Object System.Collections.Generic.List[System.Windows.Forms.Button]

    # REFRESH ENGINE:Cleanly builds layout and dynamically resizes the interface
    function Update-UIElements {
        $listPanel.Controls.Clear()
        $global:folderButtonsList.Clear()
        $buttonCount = 0

        # FIX:Sort the folders list alphabetically by the display caption ("Name") field
        $loadedFolders = Get-FoldersList | Sort-Object Name

        if ($loadedFolders.Count -eq 0) {
            $emptyLabel = New-Object System.Windows.Forms.Label
            $emptyLabel.Text = "You have no folders configured."
            $emptyLabel.Size = New-Object System.Drawing.Size($buttonWidth, $buttonHeight)
            $emptyLabel.TextAlign = "MiddleCenter"
            $emptyLabel.ForeColor = $dimTextColor
            $emptyLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10.5, [System.Drawing.FontStyle]::Italic)
            $listPanel.Controls.Add($emptyLabel)

            $global:isDeleteMode = $false
            if ($delModeBtn) {
                $delModeBtn.BackColor = $btnColor
                $delModeBtn.FlatAppearance.MouseOverBackColor = $btnHover
            }
        }
        else {
            foreach ($f in $loadedFolders) {
                $btn = New-Object System.Windows.Forms.Button
                $btn.Text = " $($f.Name)"; $btn.TextAlign = "MiddleLeft"
                $btn.Size = New-Object System.Drawing.Size($buttonWidth, $buttonHeight)
                $btn.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, $buttonMargin)
                $btn.Font = New-Object System.Drawing.Font("Segoe UI", 10.5)
                $btn.ForeColor = $textColor
                $btn.FlatStyle = "Flat"; $btn.FlatAppearance.BorderSize = 0
                $btn.FlatAppearance.MouseDownBackColor = $btnPressed

                if ($global:isDeleteMode) {
                    $btn.BackColor = $deleteColor; $btn.FlatAppearance.MouseOverBackColor = $deleteHover
                }
                else {
                    $btn.BackColor = $btnColor; $btn.FlatAppearance.MouseOverBackColor = $btnHover
                }

                $btn.Tag = $f.Name
                $btn.Add_Click({ 
                        param($clickedButton, $eventArgs)
                        if ($global:isDeleteMode) {
                            Remove-FolderEntry $clickedButton.Tag
                            Update-UIElements
                        }
                        else {
                            $targetPath = (Get-FoldersList | Where-Object { $_.Name -eq $clickedButton.Tag }).Path
                            if (Test-Path $targetPath) { Invoke-Item $targetPath }
                            else { [System.Windows.Forms.MessageBox]::Show("Folder not found: $targetPath", "Error") }
                        }
                    })

                $listPanel.Controls.Add($btn)
                $global:folderButtonsList.Add($btn)
                $buttonCount++
            }
        }

        # Calculate exact geometric boundaries dynamically
        $extraElementsHeight = 15 + 2 + 15 + $buttonHeight
        $displayCount = if ($buttonCount -eq 0) { 1 } else { $buttonCount }
        $calculatedHeight = ($displayCount * ($buttonHeight + $buttonMargin)) + $extraElementsHeight + $paddingTopBottom + $windowTitleBarHeight

        $mainPanel.Height = $calculatedHeight
        $form.Size = New-Object System.Drawing.Size($windowWidth, $calculatedHeight)
    }

    # Initial loading sweep setup
    Update-UIElements

    # Separation Line Decorative Accent Element
    $separator = New-Object System.Windows.Forms.Label
    $separator.Size = New-Object System.Drawing.Size($buttonWidth, 2); $separator.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
    $separator.Margin = New-Object System.Windows.Forms.Padding(0, 5, 0, 15); $mainPanel.Controls.Add($separator)

    # Bottom Actions Bar Custom Panel Layout Grid Array
    $actionDock = New-Object System.Windows.Forms.FlowLayoutPanel
    $actionDock.Size = New-Object System.Drawing.Size($buttonWidth, $buttonHeight); $actionDock.FlowDirection = "LeftToRight"
    $actionDock.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 0)
    $mainPanel.Controls.Add($actionDock)

    # "+ Add Folder" Action Component
    $addBtn = New-Object System.Windows.Forms.Button
    $addBtn.Text = "+ Add Folder"; $addBtn.Size = New-Object System.Drawing.Size(290, $buttonHeight); $addBtn.Margin = New-Object System.Windows.Forms.Padding(0, 0, 10, 0)
    $addBtn.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10.5, [System.Drawing.FontStyle]::Bold)
    addBtn.ForeColor = $textColor; $addBtn.BackColor = $accentColor; $addBtn.FlatStyle = "Flat"; $addBtn.FlatAppearance.BorderSize = 0
    $addBtn.FlatAppearance.MouseOverBackColor = $accentHover

    $addBtn.Add_Click({
            $dialog = New-Object System.Windows.Forms.OpenFileDialog
            $dialog.Filter = "Folders|`n"; $dialog.CheckFileExists = $false; $dialog.FileName = "Select Folder"
            $form.TopMost = $false

            if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                $selectedPath = [System.IO.Path]::GetDirectoryName($dialog.FileName)

                $inputForm = New-Object System.Windows.Forms.Form
                $inputForm.Text = "Folder Name"; $inputForm.Size = New-Object System.Drawing.Size(300, 150)
                $inputForm.StartPosition = "CenterParent"; $inputForm.FormBorderStyle = "FixedDialog"; $inputForm.TopMost = $true

                $label = New-Object System.Windows.Forms.Label; $label.Text = "Enter a display name for this folder:"; $label.Location = New-Object System.Drawing.Point(15, 15); $label.Size = New-Object System.Drawing.Size(250, 20)
                $inputForm.Controls.Add($label)

                $textBox = New-Object System.Windows.Forms.TextBox; $textBox.Location = New-Object System.Drawing.Point(15, 40); $textBox.Size = New-Object System.Drawing.Size(255, 20)
                $inputForm.Controls.Add($textBox)

                $okBtn = New-Object System.Windows.Forms.Button; $okBtn.Text = "OK"; $okBtn.Location = New-Object System.Drawing.Point(115, 75); $okBtn.DialogResult = "OK"
                $inputForm.AcceptButton = $okBtn; $inputForm.Controls.Add($okBtn)

                if ($inputForm.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK -and -not [string]::IsNullOrWhiteSpace($textBox.Text)) {
                    Add-FolderEntry $textBox.Text.Trim() $selectedPath
                    Update-UIElements
                }
            }
            $form.TopMost = $true
        })
    $actionDock.Controls.Add($addBtn)

    # "Delete Mode" Multi-Toggle Component
    $delModeBtn = New-Object System.Windows.Forms.Button
    $delModeBtn.Text = "Delete"; $delModeBtn.Size = New-Object System.Drawing.Size(100, $buttonHeight); $delModeBtn.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 0)
    $delModeBtn.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10.5, [System.Drawing.FontStyle]::Bold)
    $delModeBtn.ForeColor = $textColor; $delModeBtn.BackColor = $btnColor; $delModeBtn.FlatStyle = "Flat"; $delModeBtn.FlatAppearance.BorderSize = 0
    $delModeBtn.FlatAppearance.MouseOverBackColor = $btnHover

    $delModeBtn.Add_Click({
            if ((Get-FoldersList).Count -eq 0) { return }

            $global:isDeleteMode = -not $global:isDeleteMode
            if ($global:isDeleteMode) {
                $delModeBtn.BackColor = $deleteColor; $delModeBtn.FlatAppearance.MouseOverBackColor = $deleteHover
                foreach ($fb in $global:folderButtonsList) { $fb.BackColor = $deleteColor; $fb.FlatAppearance.MouseOverBackColor = $deleteHover }
            }
            else {
                $delModeBtn.BackColor = $btnColor; $delModeBtn.FlatAppearance.MouseOverBackColor = $btnHover
                foreach ($fb in $global:folderButtonsList) { $fb.BackColor = $btnColor; $fb.FlatAppearance.MouseOverBackColor = $btnHover }
            }
        })
    $actionDock.Controls.Add($delModeBtn)

    # Presentation Fade Engine Execution

    $timer = New-Object System.Windows.Forms.Timer; $timer.Interval = 10
    $timer.Add_Tick({ if ($form.Opacity -lt 1.0) { $form.Opacity = [Math]::Min(1.0, $form.Opacity + 0.08) } else { $timer.Stop() }
        })
    $form.Add_Load({ $timer.Start() })

    $form.ShowDialog() | Out-Null
}