Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Unblock-File -Path "Plugins\Xceed.Wpf.Toolkit.dll"
Add-Type -Path "Plugins\Xceed.Wpf.Toolkit.dll"
Add-Type -Namespace WinAPI -Name DwmApi -MemberDefinition @"
    [DllImport("dwmapi.dll")]
    public static extern int DwmExtendFrameIntoClientArea(IntPtr hWnd, ref Margins pMargins);

    [DllImport("dwmapi.dll")]
    public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);

    [StructLayout(LayoutKind.Sequential)]
    public struct Margins
    {
        public int Left, Right, Top, Bottom;
    }
"@

#Add-Type -Path "Plugins\SharpDX.dll"
#Add-Type -Path "Plugins\SharpDX.XInput.dll"
#Add-Type -Path "Plugins\SharpDXHelperLibrary.dll"

#Unblock-File -Path "Plugins\BetterFolderBrowser.dll"
#Add-Type -Path "Plugins\BetterFolderBrowser.dll"

<# START FUNCTIONS #>

function Get-WideImage {
    Add-Type -AssemblyName System.Drawing

    # Define image extensions to search for
    $imageExtensions = @("*.png", "*.jpg", "*.jpeg")

    foreach ($ext in $imageExtensions) {
        Get-ChildItem -Path $imagesPath -Filter $ext -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $img = [System.Drawing.Image]::FromFile($_.FullName)
                if ($img.Width -gt $img.Height) {
                    $img.Dispose()
                    return $_.FullName
                }
                $img.Dispose()
            } catch {
                # Ignore files that can't be read as images
            }
        }
    }
    return $null  # No wide image found
}

function MenuInstaller {
    $label.Content = "This script needs to launch an external installer. Do you want to continue?"
    $hiddenButtonInstallLocal.Visibility = "Collapsed"
    $installButton.Visibility = "Collapsed"
	$hiddenButtonPlay.Visibility = "Visible"
	$cancelButton.Content = "No"
    $hiddenButtonPlay.Add_Click({
        Start-Process $archive
        exit 1
    })
}

function MenuLANShortcut {
    $label.Text = "$gameName is installed on the LAN and may run slowly. Do you want to play from the network or install locally? You can disable this warning in the settings for the future."
    $label.Visibility = "Visible"

    $hiddenButtonPlay.Add_Click({
        StartGame
        exit 1
    })

    $hiddenButtonPlay.Visibility = "Visible"
    $hiddenButtonInstallLocal.Visibility = "Visible"
    $verifyButton.Visibility = "Collapsed"
    $hiddenButtonYes.Visibility = "Collapsed"
    $installButton.Visibility = "Collapsed"
    $cancelButton.Visibility = "Collapsed"
     
    $hiddenButtonInstallLocal.Add_Click({ 
        Menu7zInstall 
        Clear-Focus
    })
}

function MenuNewVersion {
	$label.Visibility = "Visible"
    $label.Text = "A new version of $gameName is available. Do you want to install the new version?"
    $label2.Visibility = "Visible"
    $label2.Text = "Installed Version: $installedVersion    |    New Version: $newVersionNumber"
	$hiddenButtonYes.Visibility = "Visible"
	$hiddenButtonYes.Add_Click({ 
        Menu7zInstall 
        Clear-Focus
    })
	$cancelButton.Content = "No"
    $installButton.Visibility = "Collapsed"
    $hiddenButtonPlay.Visibility = "Visible"
    $hiddenButtonPlay.Add_Click({
        StartGame
        exit 1
    })
}

function ToggleSettingsMenu {
    if ($settingsBorder.Visibility -eq "Visible") {

        $settingsBorder.Visibility = "Collapsed"
    } else {

        $settingsBorder.Visibility = "Visible"
    }
}

function OpenFolderChoice {
    $selected = Show-WpfFolderPicker
    if ($selected) {
        if ($selected[-1] -ne '\') { $selected += '\' }
        $global:DefaultInstallPath = $selected
        $installPathField.Text = $selected

    } else {
        Write-Warning "Folder selection cancelled."
    }
    SaveSettings
    Clear-Focus
}
function SaveSettings {

    $global:IgnoreLanWarning    = $ignoreLanCheck.IsChecked
    $global:DesktopShortcut     = $desktopShortcutCheck.IsChecked
    $global:DefaultInstallPath  = Normalize-PathToDoubleBackslash $installPathField.Text
    $escapedInstallPath         = Normalize-PathToDoubleBackslash $global:DefaultInstallPath

    $labelSelectedFont = if ($fontSelector.SelectedItem -ne $null) {
        $fontSelector.SelectedItem.Content
    } else {
        "Inter"
    }
    $labelFontSize = if ($fontSizeSelector.SelectedItem -ne $null) {
        $fontSizeSelector.SelectedItem.Content
    } else {
        "16"
    }
    $btnSelectedFont = if ($btnFontSelector.SelectedItem -ne $null) {
        $btnFontSelector.SelectedItem.Content
    } else {
        "Inter"
    }
    $btnFontSize  = if ($btnFontSizeSelector.SelectedItem -ne $null) {
        $btnFontSizeSelector.SelectedItem.Content
    } else {
        "16"
    }
    $titleFontSize  = if ($titleFontSizeSelector.SelectedItem -ne $null) {
        $titleFontSizeSelector.SelectedItem.Content
    } else {
        "16"
    }
    $titleSelectedFont = if ($titleFontFamilySelector.SelectedItem -ne $null) {
        $titleFontFamilySelector.SelectedItem.Content
    } else {
        "Inter"
    }

    $backgroundColor            = $backgroundPicker.SelectedColor.ToString()
    $btnBgColor                 = $btnColorPicker.SelectedColor.ToString()
    $highlightColor             = $highlightPicker.SelectedColor.ToString()
    $btnFontColor               = $btnFontColorPicker.SelectedColor.ToString()
    $labelColor                 = $labelColorPicker.SelectedColor.ToString()
    $titleFontColor             = $titleColorPicker.SelectedColor.ToString()

    $settingsContent = @"
[General]
IgnoreLanWarning=$global:IgnoreLanWarning
DesktopShortcut=$global:DesktopShortcut
DefaultInstallPath=$escapedInstallPath

[Appearance]
LabelFontFamily=$labelSelectedFont
LabelFontSize=$labelFontSize
LabelColor=$labelColor

ButtonFontFamily=$btnSelectedFont
ButtonFontSize=$btnFontSize
ButtonContainerBackground=$backgroundColor
ButtonBackground=$btnBgColor
ButtonHighlight=$highlightColor
ButtonFontColor=$btnFontColor


TitleFontFamily=$titleSelectedFont
TitleFontSize=$titleFontSize
TitleFontColor=$titleFontColor 
"@

    $settingsContent | Out-File -FilePath $global:settingsFile -Encoding UTF8  
    $installButton.Content = "Install to $DefaultInstallPath"
    foreach ($btn in $buttons) {
        $btn.InvalidateVisual()
        $btn.InvalidateMeasure()
        $btn.UpdateLayout()
    }
    ColorPaletteSwap

}

function Show-WpfFolderPicker {
    Add-Type -AssemblyName System.Windows.Forms

    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Select a Folder"
    $dialog.SelectedPath = $global:DefaultInstallPath
    $dialog.ShowNewFolderButton = $true

    $result = $dialog.ShowDialog()
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        return $dialog.SelectedPath
    } else {
        return $null
    }
}

function Menu7zInstall {
    $titleLabel.Text =  "$gameName"
    $label.Visibility = "Visible"
    $label.Text = $requiredText
    
    $hiddenButtonPlay.Visibility = "Collapsed"
    $hiddenButtonInstallLocal.Visibility = "Collapsed"
	$hiddenButtonYes.Visibility = "Collapsed"
	$cancelButton.Content = "Cancel"
    $installButton.Visibility = "Visible"
    $cancelButton.Visibility = "Visible"
    $verifyButton.Visibility = "Collapsed"

    $installButton.Add_Click({
        $WshShell = New-Object -comObject WScript.Shell
        $shortcutExePath = $originalShortcut.TargetPath
        $shortcutExePath = $shortcutExePath -replace [regex]::Escape($baseShortcutPath), $global:DefaultInstallPath
        $skippedInstall = $false
        $global:exePath = $originalShortcut.TargetPath
        Write-Host $shortcutExePath
        if (Test-Path $shortcutExePath) {
            $label.Text = "Exe already found at install path, skip install?"
            $hiddenButtonYes.Visibility = "Visible" 
            $hiddenButtonYes.Content = "Yes"
            $installButton.Visibility = "Collapsed"
            $cancelButton.Content = "No"
            $cancelButton.Remove_Click($cancelHandler)

            $global:cancelClickHandler = {
                7zipInstall
            }
            $cancelButton.Add_Click($cancelClickHandler)
            
            $yesHandler = {
                $skippedInstall = $true
                $label.Text = "Writing Settings File"
                PostInstall
            }
           
            $hiddenButtonYes.Add_Click($yesHandler)
        } else {
            7zipInstall
        }
    Clear-Focus
    })
}

function 7zipInstall {
    $archivePath = [string]$global:archive
    $extractDir = [string]$global:DefaultInstallPath
    # Wrap archive path in quotes to handle spaces
    $quotedArchive = "`"$archivePath`""
    $extractArg = "-o$extractDir"  # Do NOT quote this
    $args = @("x", $quotedArchive, $extractArg)
    $7zipProcess = Start-Process -FilePath $7zG -ArgumentList $args -PassThru -Wait
    $exitCode = $7zipProcess.ExitCode

    switch ($exitCode) {
        0 {
            Write-Host "Exit Code: $exitCode"
            PostInstall
        }
        1 {
            Write-Host "Exit Code: $exitCode"
            $7zipMsg = "Warning (some files may have been locked)"
            $label.Text = $7zipMsg + "``n`n" + $requiredText
        }
        2 {
            Write-Host "Exit Code: $exitCode"
            $7zipMsg = "Fatal error"
            $label.Text = $7zipMsg + "`n`n" + $requiredText
        }
        7 {
            Write-Host "Exit Code: $exitCode"
            $7zipMsg = "Command line error"
            $label.Text = $7zipMsg + "`n`n"+ $requiredText
        }
        8 {
            Write-Host "Exit Code: $exitCode"
            $7zipMsg = "Not enough memory for operation"
            $label.Text = $7zipMsg + "`n`n" + $requiredText
        }
        255 {
            Write-Host "Exit Code: $exitCode"
            $7zipMsg = "User cancelled operation"

            $label.Text = $7zipMsg + "`n`n" + $requiredText
        }
        Default {
            Write-Host "Exit Code: $exitCode"
            $7zipMsg = "Unknown 7-Zip exit code: $exitCode"
            $label.Text = $7zipMsg + "`n`n" + $requiredText
        }
    }
}

function Normalize-PathToDoubleBackslash {
    param (
        [string]$inputPath
    )
    $cleaned = $inputPath.Trim()
    $cleaned = $cleaned -replace '\\+', '\'
    $cleaned = $cleaned.TrimEnd('\') + '\'

    return $cleaned
}

# Helper function to enable aero glass on a window
function Enable-AeroGlass($form) {
    $hwnd = (New-Object System.Windows.Interop.WindowInteropHelper($form)).Handle

    # Extend the frame into client area (negative margin for full glass)
    $margins = New-Object WinAPI.DwmApi+Margins
    $margins.Left = -1
    $margins.Right = -1
    $margins.Top = -1
    $margins.Bottom = -1

    # Extend frame
    [WinAPI.DwmApi]::DwmExtendFrameIntoClientArea($hwnd, [ref]$margins) | Out-Null

    # Enable rounded corners if on Windows 11 (DWM Window Attribute 33 is DWMWA_WINDOW_CORNER_PREFERENCE)
    $DWMWA_WINDOW_CORNER_PREFERENCE = 33
    $DWMWCP_ROUND = 2
    $value = $DWMWCP_ROUND

    # Use the instance of $value for SizeOf, not the type [int]
    [WinAPI.DwmApi]::DwmSetWindowAttribute($hwnd, $DWMWA_WINDOW_CORNER_PREFERENCE, [ref]$value, [System.Runtime.InteropServices.Marshal]::SizeOf($value)) | Out-Null
}

function Clear-Focus {
    $dummyFocus.Focus() | Out-Null
}

function ConvertTo-Color([string]$hex) {
    if ($hex.Length -eq 7) {
        $hex = "#FF$($hex.Substring(1))"  # Prepend full opacity alpha
    }
    return [System.Windows.Media.Color]::FromArgb(
        [byte]::Parse($hex.Substring(1,2), 'HexNumber'),
        [byte]::Parse($hex.Substring(3,2), 'HexNumber'),
        [byte]::Parse($hex.Substring(5,2), 'HexNumber'),
        [byte]::Parse($hex.Substring(7,2), 'HexNumber')
    )
}

function ApplyTheme($themeSettings) {
    # Parse current settings into $settings
    $settings = @{}
    if (Test-Path $settingsFile) {
        Get-Content $settingsFile | ForEach-Object {
            $_ = $_.Trim()
            if ($_ -match '^\s*#' -or $_ -match '^\s*$') { return }

            if ($_ -match '^(.*?)\s*=\s*(.*)$') {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim()
                $settings[$key] = $value
            }
        }
    }
    # Merge theme settings
    foreach ($key in $themeSettings.Keys) {
        $settings[$key] = $themeSettings[$key]
    }

    # Update color pickers (only for values defined in the theme)
    foreach ($entry in $themeSettings.GetEnumerator()) {
        try {
            $color = [System.Windows.Media.ColorConverter]::ConvertFromString($entry.Value)
            switch ($entry.Key) {
                "TitleFontColor"             { $titleColorPicker.SelectedColor       = $color }
                "LabelColor"                 { $labelColorPicker.SelectedColor       = $color }
                "ButtonHighlight"            { $highlightPicker.SelectedColor        = $color }
                "ButtonBackground"           { $btnColorPicker.SelectedColor         = $color }
                "ButtonFontColor"            { $btnFontColorPicker.SelectedColor     = $color }
                "ButtonContainerBackground"  { $backgroundPicker.SelectedColor       = $color }
            }
        } catch {
            Write-Warning "Invalid color format for $($entry.Key): $($entry.Value)"
        }
    }

    # Build new content
    $settingsContent = @"
[General]
IgnoreLanWarning=$($settings["IgnoreLanWarning"])
DesktopShortcut=$($settings["DesktopShortcut"])
DefaultInstallPath=$($settings["DefaultInstallPath"])

[Appearance]
LabelFontFamily=$($settings["LabelFontFamily"])
LabelFontSize=$($settings["LabelFontSize"])
LabelColor=$($settings["LabelColor"])

ButtonFontFamily=$($settings["ButtonFontFamily"])
ButtonFontSize=$($settings["ButtonFontSize"])
ButtonContainerBackground=$($settings["ButtonContainerBackground"])
ButtonBackground=$($settings["ButtonBackground"])
ButtonHighlight=$($settings["ButtonHighlight"])
ButtonFontColor=$($settings["ButtonFontColor"])

TitleFontFamily=$($settings["TitleFontFamily"])
TitleFontSize=$($settings["TitleFontSize"])
TitleFontColor=$($settings["TitleFontColor"])
"@

    # Save to file
    $settingsContent | Out-File -FilePath $global:settingsFile -Encoding UTF8
    # Apply visually
    ColorPaletteSwap
}

function ColorPaletteSwap {
    # Read settings from file
    $ini = @{}
    Get-Content $settingsFile | ForEach-Object {
        if ($_ -match "^\s*([^=]+)\s*=\s*(.*)$") {
            $ini[$matches[1].Trim()] = $matches[2].Trim()
        }
    }

    # Apply settings to buttons
    $buttonHighlight     = $ini["ButtonHighlight"]
    $buttonBackground    = $ini["ButtonBackground"]
    $buttonContainerBg   = $ini["ButtonContainerBackground"]
    $buttonFontColor     = $ini["ButtonFontColor"]
    $btnFontSize         = $ini["ButtonFontSize"]
    $btnFontFamily       = $ini["ButtonFontFamily"]
    $labelColor          = $ini["LabelColor"]
    $labelFontFamily     = $ini["LabelFontFamily"]
    $labelFontSize       = $ini["LabelFontSize"]
    $titleColor          = $ini["TitleFontColor"]
    $titleFontFamily     = $ini["TitleFontFamily"]
    $titleFontSize       = $ini["TitleFontSize"]

    $brushConverter = New-Object System.Windows.Media.BrushConverter
    if ($buttonHighlight) {
        $originalBrush = $form.Resources["ButtonHighlightBrush"]

        if ($highlightBrush -ne $null) {
            $newBrush = $originalBrush.Clone()
            $newBrush.Color = ConvertTo-Color $buttonHighlight

            # Overwrite the resource
            $form.Resources["ButtonHighlightBrush"] = $newBrush
        } else {
            Write-Warning "ButtonHighlightBrush not found in form resources."
        }
    }

    if ($buttonContainerBg)  { $buttonContainerBrush    = $brushConverter.ConvertFromString($buttonContainerBg) 
        $buttonContainerBackground.Background = $buttonContainerBrush
        $settingsBorder.Background = $buttonContainerBrush
    }
    if ($buttonFontColor)    { $buttonFontColorBrush    = $brushConverter.ConvertFromString($buttonFontColor) }
    if ($labelColor)         { $labelColorBrush         = $brushConverter.ConvertFromString($labelColor) }
    if ($buttonBackground)   { $buttonBackgroundBrush   = $brushConverter.ConvertFromString($buttonBackground) }
    if ($titleColor)         { $titleColorBrush         = $brushConverter.ConvertFromString($titleColor) }



    $buttons = @(
        $cancelButton,
        $installButton,
        $verifyButton,
        $hiddenButtonYes,
        $hiddenButtonInstallLocal,
        $hiddenButtonPlay,
        $resetButton,
        $settingsCancelButton,
        $saveButton
    )

    foreach ($btn in $buttons) {
        if ($buttonBackgroundBrush) { $btn.Background = $buttonBackgroundBrush }
        if ($buttonFontColorBrush)  { $btn.Foreground = $buttonFontColorBrush }
        if ($btnFontFamily)         { $btn.FontFamily = $btnFontFamily }
        if ($btnFontSize)           { $btn.FontSize   = $btnFontSize }
    }

    $textBlocks = @(
        $txtBlock1,
        $txtBlock2,
        $txtBlock3,
        $txtBlock4,
        $txtBlock5,
        $txtBlock6,
        $txtBlock7,
        $txtBlock8,
        $txtBlock9,
        $txtBlock10,
        $txtBlock11,
        $txtBlock12,
        $txtBlock13,
        $ignoreLanCheck,
        $desktopShortcutCheck
    )
 
    foreach ($txt in $textBlocks) {
        if ($buttonFontColorBrush)  { $txt.Foreground = $buttonFontColorBrush }
    }

    # Apply label settings
    $labels = @(
        $Label,
        $Label2
    )

    foreach ($lbl in $labels) {
        if ($labelColorBrush) { $lbl.Foreground = $labelColorBrush }
        if ($labelFontFamily) { $lbl.FontFamily = $labelFontFamily }
        if ($labelFontSize)   { $lbl.FontSize   = $labelFontSize }
    }

    if ($titleLabel) {
        if ($titleFontFamily) { $titleLabel.FontFamily = $titleFontFamily }
        if ($titleFontSize)   { $titleLabel.FontSize   = $titleFontSize }
        if ($titleColorBrush) { $titleLabel.Foreground = $titleColorBrush }
    }
}

function Test-WriteablePath {
    param (
        [string]$Path
    )

    try {

        $fullPath = [System.IO.Path]::GetFullPath($Path)
        # Break path into components
        $segments = $fullPath -split '[\\/]' | Where-Object { $_ -ne '' }

        if ($segments.Count -eq 0) {
            Write-Host "Invalid or empty path after normalization."
            return $false
        }

        # Start building from the root (e.g., C:\)
        $currentPath = if ($segments[0] -match '^[a-zA-Z]:\\?$') {
            $segments[0] + '\'
        } else {
            $segments[0]
        }

        for ($i = 1; $i -lt $segments.Count; $i++) {
            $currentPath = Join-Path $currentPath $segments[$i]

            if (Test-Path $currentPath) {

                try {
                    $tempFile = Join-Path $currentPath ([System.IO.Path]::GetRandomFileName())
                    New-Item -Path $tempFile -ItemType File -Force -ErrorAction Stop | Out-Null
                    Remove-Item $tempFile -Force
                    return $true
                } catch {
                    Write-Host "Write failed at: $currentPath - $_"
                }
            } else {
                Write-Host "Path does not exist: $currentPath"
            }
        }
        Write-Host "No writeable existing parent path found."
        return $false
    } catch {
        Write-Host "Error during test: $_"
        return $false
    }
}
function PostInstall {
    $WshShell = New-Object -comObject WScript.Shell
    $shortcutExePath = $originalShortcut.TargetPath
    $shortcutExePath = $shortcutExePath -replace [regex]::Escape($baseShortcutPath), $global:defaultInstallPath
    $gameTxtFile = "$env:USERPROFILE\Documents\DadLauncher\Installed\$gameName.txt"

    # Write install info to text file
    $txtContent = @("InstalledPath=$shortcutExePath")
    if ($archiveVersion) {
        $txtContent += "Version=$archiveVersion"
    } else {
        $txtContent += "Version=0.0"
    }
    $txtContent | Set-Content -Path $gameTxtFile
    if (Test-Path $archivePathNoExt) {
        $shortcutFiles = Get-ChildItem -Path $archivePathNoExt -Filter "*.lnk" | Where-Object {
            $_.BaseName -match "^$([regex]::Escape($gameName))( \(.+\))?$"
        }

        foreach ($file in $shortcutFiles) {
            $shortcutName = $file.Name
            $targetShortcutPath = Join-Path -Path $archivePathNoExt -ChildPath $shortcutName
            $documentShortcutPath = Join-Path -Path $documentShortcutFolder -ChildPath $shortcutName
            $desktopShortcutPath = Join-Path -Path ([Environment]::GetFolderPath('Desktop')) -ChildPath $shortcutName
            try {
                # Create the shortcut in document folder first
                $originalShortcutObj = $WshShell.CreateShortcut($targetShortcutPath)
                $newShortcut = $WshShell.CreateShortcut($documentShortcutPath)

                $targetPath = $originalShortcutObj.TargetPath -replace [regex]::Escape($baseShortcutPath), $global:DefaultInstallPath
                $iconLocation = $originalShortcutObj.IconLocation -replace [regex]::Escape($baseShortcutPath), $global:DefaultInstallPath

                $newShortcut.TargetPath = $targetPath
                $newShortcut.WorkingDirectory = [System.IO.Path]::GetDirectoryName($targetPath)
                $newShortcut.IconLocation = $iconLocation
                $newShortcut.Arguments = $originalShortcutObj.Arguments
                $newShortcut.Description = $originalShortcutObj.Description
                $newShortcut.Save()
            } catch {
                Write-Warning "Error creating Document shortcut: $_"
            }

            # Copy shortcut to Desktop if enabled
            if ($global:DesktopShortcut -eq $true) {
                try {
                    Copy-Item -Path $documentShortcutPath -Destination $desktopShortcutPath -Force
                } catch {
                    Write-Warning "Error copying shortcut to Desktop: $_"
                }
            }
        }
    }
    
    $global:exePath = $shortcutExePath

    # click handler
    $verifyHandler = {
        if (-not (Test-Path $7z)) {
            [System.Windows.MessageBox]::Show("7z.exe not found at $7z")
            return
        }

        $sfvPath = "$hashPaths\$gameNameOriginal.sfv" 
        if (-not (Test-Path $sfvPath)) {
            [System.Windows.MessageBox]::Show("SFV file not found: $sfvPath")
            return
        }

        $targetFolder = Split-Path $global:exePath -Parent
        $targetFolder = Split-Path $targetFolder -Parent


        $mismatches = @()
        $checkedCount = 0
        $numError = 0
        $lines = Get-Content $sfvPath

        $targetFolderName = Split-Path $targetFolder -Leaf

        # Filter valid SFV lines (non-empty, not comments)
        $validLines = $lines | Where-Object { $_.Trim() -ne "" -and -not $_.Trim().StartsWith(";") }

        $totalExpected = $validLines.Count

        foreach ($line in $validLines) {
            $line = $line.Trim()
            if ($line -eq "" -or $line.StartsWith(";")) { continue }
            $lastSpaceIndex = $line.LastIndexOf(' ')
            if ($lastSpaceIndex -lt 0) { continue }
            $relativePath = $line.Substring(0, $lastSpaceIndex)
            $expectedCrc = $line.Substring($lastSpaceIndex + 1).ToUpperInvariant()

            # Then your path fix if needed, e.g.:

            $targetFolderName = Split-Path $targetFolder -Leaf
            if ($relativePath.StartsWith("$targetFolderName\")) {
                $relativePath = $relativePath.Substring($targetFolderName.Length + 1)
            }

            $localPath = Join-Path $targetFolder $relativePath

            if (-not (Test-Path $localPath)) {
                $mismatches += "Missing: $relativePathFixed"
                continue
            }

            # Use 7z to compute CRC
            $out = & $7z h -scrcCRC32 "$localPath"
            $crcMatch = $out | Select-String -Pattern 'CRC32\s+for\s+data:\s*([A-Fa-f0-9]{8})'

            if ($crcMatch) {
                $actualCrc = $crcMatch.Matches[0].Groups[1].Value.ToUpperInvariant()
            } else {
                $actualCrc = ""
                Write-Warning "Could not extract CRC for: $relativePath"
                [System.Windows.MessageBox]::Show("Could not extract CRC for: $relativePath")
            }
            $checkedCount++

            if ($actualCrc -ne $expectedCrc) {
                $numError++
                $mismatches += "Mismatch: $relativePath`nExpected: $expectedCrc`nActual:   $actualCrc`n"
                Write-Host "CHECKED: $checkedCount/$totalExpected BAD: $numError | $relativePath failed CRC EXPECTED: '$expectedCrc' ACTUAL: '$actualCrc'" -ForegroundColor Red
                [System.Windows.MessageBox]::Show("CHECKED: $checkedCount/$totalExpected BAD: $numError | $relativePath failed CRC EXPECTED: '$expectedCrc' ACTUAL: '$actualCrc'")
            }else{
                Write-Host "CHECKED: $checkedCount/$totalExpected BAD: $numError | $relativePath matches CRC '$expectedCrc'"
                
            }
        }

        if ($mismatches.Count -eq 0) {
            Write-Host "`nAll files verified!" -ForegroundColor Green
            [System.Windows.MessageBox]::Show("All files verified!")
            $label.Text = "All files verified! Launch the game?"
            $cancelButton.Add_Click({exit})
            $cancelButton.Visibility = "Visible"
            $verifyButton.Visibility = "Collapsed"
            $hiddenButtonYes.Content = "Play"
            
        } else {
            Write-Host "CRC check completed with errors:`n`n" + ($mismatches -join "`n") -ForegroundColor Red
            [System.Windows.MessageBox]::Show("CRC check completed with errors:`n`n" + ($mismatches -join "`n"))
            $label.Text = "Some files did not copy correctly! Please review the log."
            $cancelButton.Add_Click({exit 1})
            $hiddenButtonYes.Content = "Play"
        }
    }

    $launchHandler = {
        StartGame
        exit 1
    }

    $installButton.Visibility = "Collapsed"
    $hiddenButtonYes.Visibility = "Visible"
    $cancelButton.Visibility = "Collapsed"
    $verifyButton.Visibility = "Visible"
    $hiddenButtonYes.Content = "Play"
    $Label.Text = "Do you want to launch the game?"
    $verifyButton.Content = "Verify Files"
    if ($cancelClickHandler){
        $cancelButton.Remove_Click($cancelClickHandler)
    }
    $hiddenButtonYes.Add_Click($launchHandler)
    $verifyButton.Add_Click($verifyHandler)

}

function Get-ShortcutTarget([string]$shortcutPath) {
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    return $shortcut.TargetPath
}

function StartGame {
    # Try 1 - Direct Shortcut Launch
    if ($documentShortcut -and (Test-Path $documentShortcut)) {
        $targetPath = Get-ShortcutTarget $documentShortcut
        if ($targetPath -and (Test-Path $targetPath)) {
            Start-Process $documentShortcut
            Start-Sleep -Seconds 1
            exit 0
        }

        # Try 2 - Modified Target Path
        if ($targetPath -and $targetPath.StartsWith($baseShortcutPath)) {
            $modifiedTargetPath = $targetPath -replace [regex]::Escape($baseShortcutPath), $DefaultInstallPath
            if (Test-Path $modifiedTargetPath) {
                Start-Process $modifiedTargetPath
                Start-Sleep -Seconds 1
                exit 0
            }
        }
    }

    # Try 3 - Read from gameTxtFile (InstalledPath)
    if (Test-Path $gameTxtFile) {
        $gameSettings = @{}
        Get-Content $gameTxtFile | ForEach-Object {
            if ($_ -match '^\s*([^=]+)\s*=\s*(.*)$') {
                $gameSettings[$matches[1].Trim()] = $matches[2].Trim()
            }
        }
        $exePath = $gameSettings["InstalledPath"]
        if ($exePath -and (Test-Path $exePath)) {
            Start-Process -FilePath $exePath -WorkingDirectory (Split-Path $exePath -Parent)
            Start-Sleep -Seconds 1
            exit 0
        }
    }
    Menu7zInstall
}

<# END FUNCTIONS #>

<# CONSTANTS #>

#TODO: Check Registry for 7zip
$7z                         = "C:\Program Files\7-Zip\7z.exe"
$7zG                        = "C:\Program Files\7-Zip\7zG.exe"
#TODO: Stop relying on shortcuts, just use the archive as the argument, and then copy shortcuts from the archivePath
$baseShortcutPath           = "D:\Games\PC\"
$dadLauncherFolder          = "$env:USERPROFILE\Documents\DadLauncher"
$documentShortcutFolder     = "$dadLauncherFolder\Shortcuts\"
#TODO: Let the user set these variables if not set in settings
$archivePath                = "D:\Games\Archives\"
$hashPaths                  = "$archivePath\.Hashes"
$xamlPath                   = "Views\GameLaunchMenu.xaml"


if ($args.Length -eq 0) {
    Write-Host "No arguments provided."
    [System.Windows.MessageBox]::Show("No arguments provided.")
    exit 1
}

if (-not (Test-Path $7z)) {
    Write-Host "7z not found, please install 7z."
    [System.Windows.MessageBox]::Show("7z not found, please install 7z.")
    exit 1
}

$shortcut = $args[0]
$databaseID = $args[1]
$playniteDir = $args[2]

$logoPath = Join-Path $playniteDir "ExtraMetadata\games\$databaseID\Logo.png"
$imagesPath = Join-Path $playniteDir "library\files\$databaseID\"

$wideImagePath = Get-WideImage
$originalShortcut = (New-Object -ComObject WScript.Shell).CreateShortcut($shortcut)

$exeArgs = $originalShortcut.Arguments

# I tried to combine this and it doesn't work
$gameNameOriginal = [System.IO.Path]::GetFileNameWithoutExtension($shortcut)
$documentShortcut = -join("$documentShortcutFolder", "$gameNameOriginal", ".lnk")
$gameName = $gameNameOriginal -replace '\(.*\)', ''
$gameName = $gameName.TrimEnd()

# Settings Folder Setup
if (-not (Test-Path -Path $dadLauncherFolder)) {
	New-Item -Path $dadLauncherFolder -ItemType Directory
} else {
}

$installedFolder = Join-Path -Path $dadLauncherFolder -ChildPath "Installed"

if (-not (Test-Path -Path $installedFolder)) {
	New-Item -Path $installedFolder -ItemType Directory
}

# Settings Block
$global:settingsFile = Join-Path -Path $dadLauncherFolder -ChildPath "settings.ini"
# Default fallback values for all settings
$defaultSettings = @{
        IgnoreLanWarning           = $false
        DesktopShortcut            = $true
        DefaultInstallPath         = "C:\Games\PC\"

        ButtonHighlight            = "#FF696969"
        ButtonBackground           = "#FF191919"
        ButtonFontColor            = "#FFFFFFFF"
        ButtonContainerBackground  = "#FF202020"
        LabelColor                 = "#FFFFFFFF"
        LabelFontFamily            = "Inter"
        LabelFontSize              = "16"
        ButtonFontFamily           = "Inter"
        ButtonFontSize             = "16"
        TitleFontFamily            = "Inter"
        TitleFontSize              = "60"
        TitleFontColor             = "#FFFFFFFF"
}
$darkSettings = @{
        ButtonHighlight            = "#FF696969"
        ButtonBackground           = "#FF191919"
        ButtonFontColor            = "#FFFFFFFF"
        ButtonContainerBackground  = "#FF202020"
        LabelColor                 = "#FFFFFFFF"
}

$lightSettings = @{
        ButtonHighlight            = "#FF50b8fe"
        ButtonBackground           = "#FFd0dbed "
        ButtonFontColor            = "#FF000000"
        ButtonContainerBackground  = "#FFf2f4f4"
        LabelColor                 = "#FF000000"
        TitleFontColor             = "#FFFFFFFF"
}
$blackSettings = @{
        ButtonHighlight            = "#FF191919"
        ButtonBackground           = "#FF000000"
        ButtonFontColor            = "#FFFFFFFF"
        ButtonContainerBackground  = "#FF000000"
        LabelColor                 = "#FFFFFFFF"
        TitleFontColor             = "#FFFFFFFF"
}
$pastelSettings = @{
        ButtonHighlight            = "#FFc9eaea"
        ButtonBackground           = "#FFedbbc8"
        ButtonFontColor            = "#FF000000"
        ButtonContainerBackground  = "#FFf7e7f2"
        LabelColor                 = "#FF000000"
        TitleFontColor             = "#FFFFFFFF"
}
# Load and parse settings.ini
$settings = @{}
if (Test-Path $settingsFile) {
    Get-Content $settingsFile | ForEach-Object {
        $_ = $_.Trim()
        if ($_ -match '^\s*#' -or $_ -match '^\s*$') { return }

        if ($_ -match '^(.*?)\s*=\s*(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            $settings[$key] = $value
        }
    }
}

# Apply defaults for any missing keys
$invalidSettings = $false
foreach ($key in $defaultSettings.Keys) {
    if (-not $settings.ContainsKey($key)) {
        $settings[$key] = $defaultSettings[$key]
        $invalidSettings = $true
    }
}

# Validate and assign typed globals
$global:IgnoreLanWarning = if ($settings.IgnoreLanWarning -match '^(true|false)$') {
    [bool]::Parse($settings.IgnoreLanWarning)
} else {
    $invalidSettings = $true
    [bool]::Parse($defaultSettings.IgnoreLanWarning)
}


$global:DesktopShortcut = if ($settings.DesktopShortcut -match '^(true|false)$') {
    [bool]::Parse($settings.DesktopShortcut)
} else {
    $invalidSettings = $true
    [bool]::Parse($defaultSettings.DesktopShortcut)
}
$installPath = $settings.DefaultInstallPath.Trim()

$global:DefaultInstallPath = if (
    -not $installPath -or
    -not (Test-WriteablePath $installPath)
) {
    $invalidSettings = $true
    $defaultSettings.DefaultInstallPath
} else {
    $installPath
}


# Save corrected settings back if needed
if ($invalidSettings -eq $true) {
    $correctedSettings = foreach ($key in $defaultSettings.Keys) {
        "$key=$($settings[$key])"
    }
    $correctedSettings | Out-File -FilePath $settingsFile -Encoding UTF8
}
$archivePathNoExt = "$archivePath$gameName"
$archivePath = "$archivePath$gameName"

# Archive Tests
$archivePathBat = Get-ChildItem -Path "$archivePath" -Filter "$gameName*.bat" | Select-Object -First 1
$archivePath7z  = Get-ChildItem -Path "$archivePath" -Filter "$gameName*.7z"  | Select-Object -First 1


if ($archivePathBat) {
	$global:archive = $archivePathBat.FullName
	$global:Bat7z = "Bat"
} elseif ($archivePath7z) {
	$global:archive = $archivePath7z.FullName
	$global:Bat7z = "7z"
} else {
	Write-Warning "Archive not found: $archive"
    [System.Windows.MessageBox]::Show("Archive not found: $archive")
    exit 1
}

if ($archive -match "\[(\d+(\.\d+)*)\]") {
	$global:archiveVersion = $matches[1]  # This will capture the version from the match
} else {
	$global:archiveVersion = 0
}

# If the shortcut is usable, it's installed on my D:\Games\PC
if (Test-Path $shortcut) {
    $global:originalShortcutPath = $originalShortcut.TargetPath

    if (Test-Path $originalShortcutPath) {
        $global:isLAN = 1
    }
} else {
    Write-Warning "Invalid argument passed."
    [System.Windows.MessageBox]::Show("Invalid argument passed.")
    exit 1
}

# Unpacked Archive Size
$lastLine = & $7z l "$archive" | Select-Object -Last 1
$lastLine = $lastLine.Trim()
if ($lastLine -match '^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\s+(\d+)\s+(\d+)\s+(\d+)\s+files,\s+(\d+)\s+folders$') {
    $originalSize = [int64]$matches[1]
    $bytes = $originalSize
    if ($bytes -ge 1TB) {
        $global:readableSize = "{0:N2} TB" -f ($bytes / 1TB)
    } elseif ($bytes -ge 1GB) {
        $global:readableSize = "{0:N2} GB" -f ($bytes / 1GB)
    } elseif ($bytes -ge 1MB) {
        $global:readableSize = "{0:N2} MB" -f ($bytes / 1MB)
    } elseif ($bytes -ge 1KB) {
        $global:readableSize = "{0:N2} KB" -f ($bytes / 1KB)
    } else {
        $global:readableSize = "$bytes bytes"
    }

    $global:requiredText = "Required Space: $readableSize"
} else {
    Write-Host "Last line did not match expected format:`n$lastLine"
}

$gameTxtFile = "$dadLauncherFolder\Installed\$gameName.txt"

if (Test-Path -Path $gameTxtFile) {
	$txtFileSettings = @{}
	Get-Content -Path $gameTxtFile | ForEach-Object {
		if ($_ -match '^(.*?)=(.*)$') {
			$txtFileSettings[$matches[1].Trim()] = $matches[2].Trim()
		}
	}
	$global:installedPath = $txtFileSettings["InstalledPath"]
	$global:installedVersion = $txtFileSettings["Version"]
    $exePath = $installedPath

    if (-not $installedVersion) {
        $installedVersion = "0.0"
    }
    if ($archiveVersion -and ([version]$archiveVersion) -gt ([version]$installedVersion)) {
        $newVersionNumber = $archiveVersion
    } else {
        try{
            StartGame
        }catch{
            Remove-Item -Path $gameTxtFile
        }
    }
}

#Load from the xaml file
$global:form              = [Windows.Markup.XamlReader]::Load([System.Xml.XmlReader]::Create($xamlPath))
Enable-AeroGlass $form

$form.DataContext         = [PSCustomObject]@{ Archive = $archive }

#Main Menu Vars
$label                        = $form.FindName("Label")
$label2                       = $form.FindName("Label2")
$titleLabel                   = $form.FindName("TitleLabel")
$minimizeButton               = $form.FindName("TitleButtonMinimize")
$maximizeButton               = $form.FindName("TitleButtonMaximize")
$closeButton                  = $form.FindName("TitleButtonClose")
$settingsButton               = $form.FindName("BottomSettingsButton")
$cancelButton                 = $form.FindName("CancelButton")
$verifyButton                 = $form.FindName("VerifyButton")      
$hiddenButtonYes              = $form.FindName("HiddenButtonYes")
$hiddenButtonInstallLocal     = $form.FindName("HiddenButtonInstallLocal")
$hiddenButtonPlay             = $form.FindName("HiddenButtonPlay")
$installButton                = $form.FindName("InstallButton")
$logoImage                    = $form.FindName("Logo")
$wideImage                    = $form.FindName("WideImage")
$dummyFocus                   = $form.FindName("DummyFocusBox")
$buttonContainerBackground    = $form.FindName("ButtonContainerBackground")
$highlightBrush               = $form.Resources["ButtonHighlightBrush"]
$settingsBorder               = $form.FindName("SettingsBorder")
#Settings Menu Vars
$settingsCloseButton  = $form.FindName("SettingsTitleButtonClose")
$ignoreLanCheck       = $form.FindName("LanCheckBox")
$desktopShortcutCheck = $form.FindName("DesktopShortcutCheckBox")
$installPathField     = $form.FindName("InstallPathField")
$installPathButton    = $form.FindName("InstallPathButton")
$installPathButton2   = $form.FindName("InstallPathButton2")
$fontSelector         = $form.FindName("FontFamilySelector")
$fontSizeSelector     = $form.FindName("FontSizeSelector")
$btnFontSelector      = $form.FindName("ButtonFontFamilySelector")
$btnFontSizeSelector  = $form.FindName("ButtonFontSizeSelector")
$backgroundPicker     = $form.FindName("BackgroundPicker")
$btnColorPicker       = $form.FindName("ButtonBackgroundPicker")
$highlightPicker      = $form.FindName("ButtonHighlightPicker")
$btnFontColorPicker   = $form.FindName("ButtonFontColorPicker")
$labelColorPicker     = $form.FindName("LabelColorPicker")
$resetButton          = $form.FindName("ResetSettingsButton")
$settingsCancelButton = $form.FindName("SettingsCancelButton")
$saveButton           = $form.FindName("SaveSettingsButton")
$titleFontFamilySelector       = $form.FindName("TitleFontFamilySelector")
$titleFontSizeSelector         = $form.FindName("TitleFontSizeSelector")
$titleColorPicker              = $form.FindName("TitleColorPicker")
$blackBtn                      = $form.FindName("BlackButton")
$darkBtn                       = $form.FindName("DarkButton")
$lightBtn                      = $form.FindName("LightButton")
$pastelBtn                     = $form.FindName("PastelButton")

$txtBlock1                     = $form.FindName("TextBlock1")
$txtBlock2                     = $form.FindName("TextBlock2")
$txtBlock3                     = $form.FindName("TextBlock3")
$txtBlock4                     = $form.FindName("TextBlock4")
$txtBlock5                     = $form.FindName("TextBlock5")
$txtBlock6                     = $form.FindName("TextBlock6")
$txtBlock7                     = $form.FindName("TextBlock7")
$txtBlock8                     = $form.FindName("TextBlock8")
$txtBlock9                     = $form.FindName("TextBlock9")
$txtBlock10                    = $form.FindName("TextBlock10")
$txtBlock11                    = $form.FindName("TextBlock11")
$txtBlock12                    = $form.FindName("TextBlock12")
$txtBlock13                    = $form.FindName("TextBlock13")

$settingsCancelButton.Add_Click({
    $settingsBorder.Visibility = "Collapsed"
})

$settingsCloseButton.Add_Click({
    $settingsBorder.Visibility = "Collapsed"
})
$lightBtn.Add_Click({
    ApplyTheme $lightSettings
})

$darkBtn.Add_Click({
    ApplyTheme $darkSettings
})
$pastelBtn.Add_Click({
    ApplyTheme $pastelSettings
})
$blackBtn.Add_Click({
    ApplyTheme $blackSettings
})
# Force a WinForms application context
$installPathButton.Add_Click({
    OpenFolderChoice
})
$installPathButton2.Add_Click({
    OpenFolderChoice
})

if (Test-Path $settingsFile) {
    $settings = Get-Content $settingsFile | ForEach-Object {
        $parts = $_ -split '=', 2
        if ($parts.Length -eq 2) {
            [PSCustomObject]@{ Key = $parts[0].Trim(); Value = $parts[1].Trim() }
        }
    }

    foreach ($entry in $settings) {
        switch ($entry.Key) {
            "IgnoreLanWarning"       { $ignoreLanCheck.IsChecked = [bool]::Parse($entry.Value) }
            "DesktopShortcut"        { $desktopShortcutCheck.IsChecked = [bool]::Parse($entry.Value) }
            "DefaultInstallPath"     { 
                $installPathField.Text = $entry.Value
                $global:DefaultInstallPath = $entry.Value
            }

            "ButtonHighlight"        { $highlightPicker.SelectedColor = [System.Windows.Media.Color]([System.Windows.Media.ColorConverter]::ConvertFromString($entry.Value)) }
            "ButtonBackground"       { $btnColorPicker.SelectedColor  = [System.Windows.Media.Color]([System.Windows.Media.ColorConverter]::ConvertFromString($entry.Value)) }
            "ButtonFontColor"        { $btnFontColorPicker.SelectedColor = [System.Windows.Media.Color]([System.Windows.Media.ColorConverter]::ConvertFromString($entry.Value)) }
            "ButtonContainerBackground" { $backgroundPicker.SelectedColor = [System.Windows.Media.Color]([System.Windows.Media.ColorConverter]::ConvertFromString($entry.Value)) }
            "LabelColor"             { $labelColorPicker.SelectedColor = [System.Windows.Media.Color]([System.Windows.Media.ColorConverter]::ConvertFromString($entry.Value)) }



            "TitleFontFamily"    { $titleFontFamilySelector.SelectedItem = $titleFontFamilySelector.Items | Where-Object { $_.Content -eq $entry.Value } }
            "TitleFontSize"      { $titleFontSizeSelector.SelectedValuePath = "Content"; $titleFontSizeSelector.SelectedValue = $entry.Value }
            "TitleFontColor"     { $titleColorPicker.SelectedColor = [System.Windows.Media.Color]([System.Windows.Media.ColorConverter]::ConvertFromString($entry.Value)) }
        }
    }
}

$fontSizes = @(8, 9, 10, 11, 12, 14, 16, 18, 20, 22, 24, 26, 28, 32, 36, 48, 60, 72, 84, 96, 110 , 122, 134)

# Populate Label FontFamily selector
$lastFont = $settings | Where-Object { $_.Key -eq "LabelFontFamily" } | Select-Object -ExpandProperty Value
[System.Windows.Media.Fonts]::SystemFontFamilies | Sort-Object Source | ForEach-Object {
    $fontItem = New-Object System.Windows.Controls.ComboBoxItem
    $fontItem.Content = $_.Source
    $fontItem.FontFamily = $_
    $null = $fontSelector.Items.Add($fontItem)  # suppress output

    if ($_.Source -eq $lastFont) {
        $fontSelector.SelectedItem = $fontItem
    }
}

$lastFontSize = $settings | Where-Object { $_.Key -eq "LabelFontSize" } | Select-Object -ExpandProperty Value

# Populate Label FontSize selector
$fontSizes | ForEach-Object {
    $sizeItem = New-Object System.Windows.Controls.ComboBoxItem
    $sizeItem.Content = $_
    $null = $fontSizeSelector.Items.Add($sizeItem)

    if ($_ -eq $lastFontSize) {
        $fontSizeSelector.SelectedItem = $sizeItem
    }
}

$lastBtnFontSize = $settings | Where-Object { $_.Key -eq "ButtonFontSize" } | Select-Object -ExpandProperty Value

# Populate Button FontSize selector
$fontSizes | ForEach-Object {
    $sizeItem = New-Object System.Windows.Controls.ComboBoxItem
    $sizeItem.Content = $_
    $null = $btnFontSizeSelector.Items.Add($sizeItem)

    if ($_ -eq $lastBtnFontSize) {
        $btnFontSizeSelector.SelectedItem = $sizeItem
    }
}

# Populate Button FontFamily selector
$lastbtnFont = $settings | Where-Object { $_.Key -eq "ButtonFontFamily" } | Select-Object -ExpandProperty Value
[System.Windows.Media.Fonts]::SystemFontFamilies | Sort-Object Source | ForEach-Object {
    $fontItem = New-Object System.Windows.Controls.ComboBoxItem
    $fontItem.Content = $_.Source
    $fontItem.FontFamily = $_
    $null = $btnFontSelector.Items.Add($fontItem)

    if ($_.Source -eq $lastbtnFont) {
        $btnFontSelector.SelectedItem = $fontItem
    }
}

$lastTitleFont = $settings | Where-Object { $_.Key -eq "TitleFontFamily" } | Select-Object -ExpandProperty Value
[System.Windows.Media.Fonts]::SystemFontFamilies | Sort-Object Source | ForEach-Object {
    $fontItem = New-Object System.Windows.Controls.ComboBoxItem
    $fontItem.Content = $_.Source
    $fontItem.FontFamily = $_
    $null = $titleFontFamilySelector.Items.Add($fontItem)

    if ($_.Source -eq $lastTitleFont) {
        $titleFontFamilySelector.SelectedItem = $fontItem
    }
}

$lastTitleFontSize = $settings | Where-Object { $_.Key -eq "TitleFontSize" } | Select-Object -ExpandProperty Value

$fontSizes | ForEach-Object {
    $sizeItem = New-Object System.Windows.Controls.ComboBoxItem
    $sizeItem.Content = $_
    $null = $titleFontSizeSelector.Items.Add($sizeItem)

    if ($_ -eq $lastTitleFontSize) {
        $titleFontSizeSelector.SelectedItem = $sizeItem
    }
}

$resetButton.Add_Click({
    $ignoreLanCheck.IsChecked       = $defaultSettings.IgnoreLanWarning
    $desktopShortcutCheck.IsChecked = $defaultSettings.DesktopShortcut
    $installPathField.Text          = $defaultSettings.DefaultInstallPath

    $highlightPicker.SelectedColor      = ConvertTo-Color($defaultSettings.ButtonHighlight)
    $btnColorPicker.SelectedColor       = ConvertTo-Color($defaultSettings.ButtonBackground)
    $btnFontColorPicker.SelectedColor   = ConvertTo-Color($defaultSettings.ButtonFontColor)
    $labelColorPicker.SelectedColor     = ConvertTo-Color($defaultSettings.LabelColor)
    $backgroundPicker.SelectedColor     = ConvertTo-Color($defaultSettings.ButtonContainerBackground)

    # Reset Font Selector
    $fontSelector.SelectedItem = $fontSelector.Items | Where-Object { $_.Content -eq $defaultSettings.LabelFontFamily }
    $btnFontSelector.SelectedItem = $btnFontSelector.Items | Where-Object { $_.Content -eq $defaultSettings.ButtonFontFamily }

    $fontSizeSelector.SelectedValuePath = "Content"
    $btnFontSizeSelector.SelectedValuePath = "Content"
    $fontSizeSelector.SelectedValue = $defaultSettings.LabelFontSize
    $btnFontSizeSelector.SelectedValue = $defaultSettings.ButtonFontSize

    $titleFontFamilySelector.SelectedItem = $titleFontFamilySelector.Items | Where-Object { $_.Content -eq $defaultSettings.TitleFontFamily }

    $titleFontSizeSelector.SelectedValuePath = "Content"
    $titleFontSizeSelector.SelectedValue = $defaultSettings.TitleFontSize

    $titleColorPicker.SelectedColor = ConvertTo-Color($defaultSettings.TitleFontColor)

    Clear-Focus
})  

$saveButton.Add_Click({
    SaveSettings
    ToggleSettingsMenu
})


ToggleSettingsMenu
ColorPaletteSwap

$form.add_Loaded({
    $form.Icon = $iconPath
})

$form.Add_MouseLeftButtonDown({$form.DragMove()})
$form.Add_KeyDown({
    param($sender, $e)

    # Get current focused element
    $focused = [System.Windows.Input.Keyboard]::FocusedElement

    # If nothing meaningful is focused (null or just the Window itself)
    if (-not $focused -or $focused -is [System.Windows.Window]) {
        if ($InstallButton.Visibility -eq 'Visible') {
            $InstallButton.Focus() | Out-Null
        } elseif ($HiddenButtonYes.Visibility -eq 'Visible') {
            $HiddenButtonYes.Focus() | Out-Null
        }elseif ($HiddenButtonPlay.Visibility -eq 'Visible') {
            $HiddenButtonPlay.Focus() | Out-Null
            return
        }
        return
    }

    switch ($e.Key) {
        'Up'    { $direction = [System.Windows.Input.FocusNavigationDirection]::Up }
        'Down'  { $direction = [System.Windows.Input.FocusNavigationDirection]::Down }
        'Left'  { $direction = [System.Windows.Input.FocusNavigationDirection]::Left }
        'Right' { $direction = [System.Windows.Input.FocusNavigationDirection]::Right }
        default { return }
    }

    $request = New-Object System.Windows.Input.TraversalRequest $direction

    if ($focused -is [System.Windows.FrameworkElement]) {
        $focused.MoveFocus($request) | Out-Null
        $e.Handled = $true
    }
})
# Maximize / Restore toggle
$maximizeButton.Add_Click({
    if ($form.WindowState -eq 'Normal') {
        $form.WindowState = 'Maximized'
        # Change icon to restore down
        $maximizeButton.Content = [char]0xE923  # Restore Down icon
        $maximizeButton.ToolTip = "Restore Down"
        Clear-Focus
    } else {
        $form.WindowState = 'Normal'
        # Change icon to maximize
        $maximizeButton.Content = [char]0xE922  # Maximize icon
        $maximizeButton.ToolTip = "Maximize"
        Clear-Focus
    }
})

# Optional: Reset maximize button icon if window state changes by other means
$form.Add_StateChanged({
    if ($form.WindowState -eq 'Maximized') {
        $maximizeButton.Content = [char]0xE923
        $maximizeButton.ToolTip = "Restore Down"
        Clear-Focus
    } else {
        $maximizeButton.Content = [char]0xE922
        $maximizeButton.ToolTip = "Maximize"
        Clear-Focus
    }
})

$installButton.Content    = "Install to $global:DefaultInstallPath"
$cancelHandler = {exit 1}

$cancelButton.Add_Click($cancelHandler)

$minimizeButton.Add_Click({
    $form.WindowState = "Minimized"
    Clear-Focus
})

$closeButton.Add_Click({
    $form.Close()
})

$settingsButton.Add_Click({
    ToggleSettingsMenu
})
<# Xinput Block

# First, cast the enum properly
$userIndex = [SharpDX.XInput.UserIndex]::One

# Now create the controller with the cast value
$controller = New-Object SharpDX.XInput.Controller $userIndex
$prevState = $null

# Timer for polling input
$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(1000)  # Start with slower polling

$timer.Add_Tick({
    if (-not $controller.IsConnected) {
        $timer.Interval = [TimeSpan]::FromMilliseconds(1000)  # Stay slow if still not connected
        return
    }

    # If connected and timer is still slow, speed it up
    if ($timer.Interval.TotalMilliseconds -ne 100) {
        $timer.Interval = [TimeSpan]::FromMilliseconds(100)
    }

    $state = $controller.GetState()
    $buttons = $state.Gamepad.Buttons
    $thumbY = $state.Gamepad.LeftThumbY
    $thumbX = $state.Gamepad.LeftThumbX

    if ($prevState -ne $null -and $state.PacketNumber -eq $prevState.PacketNumber) {
        return  # No new input
    }
    $prevState = $state

    $focusDirection = $null
    if ($buttons.HasFlag([SharpDX.XInput.GamepadButtonFlags]::DPadUp)) {
        $focusDirection = "Up"
    } elseif ($buttons.HasFlag([SharpDX.XInput.GamepadButtonFlags]::DPadDown)) {
        $focusDirection = "Down"
    } elseif ($buttons.HasFlag([SharpDX.XInput.GamepadButtonFlags]::DPadLeft)) {
        $focusDirection = "Left"
    } elseif ($buttons.HasFlag([SharpDX.XInput.GamepadButtonFlags]::DPadRight)) {
        $focusDirection = "Right"
    }

    if ($focusDirection) {
        $request = New-Object System.Windows.Input.TraversalRequest ([System.Windows.Input.FocusNavigationDirection]::$focusDirection)
        $focused = [System.Windows.Input.Keyboard]::FocusedElement
        if ($focused -and $focused -is [System.Windows.FrameworkElement]) {
            $focused.MoveFocus($request) | Out-Null
        }
    }

    # A button = "Enter", B button = "Escape"
    if ($buttons.HasFlag([SharpDX.XInput.GamepadButtonFlags]::A)) {
        $focused = [System.Windows.Input.Keyboard]::FocusedElement
        if ($focused -and $focused -is [System.Windows.Controls.Button]) {
            $focused.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))
        }
    }
})

$timer.Start()
#>

# Loading Images from Playnite
if ($logoPath) {
    try{
        $stream = [System.IO.File]::OpenRead($logoPath)
        $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
        $bitmap.BeginInit()
        $bitmap.StreamSource = $stream
        $bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bitmap.EndInit()
        $bitmap.Freeze()    #Makes it cross-thread accessible
        $stream.Close()
        $LogoImage.Source = $bitmap
    
        # Hide the label if logo is present
        $titleLabel.Visibility = "Collapsed"
    }catch{
        Write-Warning "Error loading logo from path: $logoPath"
        # Show the label if logo is missing
        $LogoImage.Visibility = "Collapsed"
        $titleLabel.Visibility = "Visible"
    }
} else {
    # Show the label if logo is missing
    $LogoImage.Visibility = "Collapsed"
    $titleLabel.Visibility = "Visible"
}

if ($wideImagePath) {
    try {
        $stream = [System.IO.File]::OpenRead($wideImagePath)
        $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
        $bitmap.BeginInit()
        $bitmap.StreamSource = $stream
        $bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bitmap.EndInit()
        $bitmap.Freeze()  
        $stream.Close()
        $WideImage.Source = $bitmap
    } catch {
    }
}


# Checks for alt menus
if ($newVersionNumber) {
    MenuNewVersion
} elseif ($isLAN -eq 1) {
    if ($global:IgnoreLanWarning -eq $true) {
        StartGame
    } else {
        MenuLANShortcut
    }
} else {
    if ($global:Bat7z -eq "Bat") {
        MenuInstaller
    } 
    else {
        if ($documentShortcut -and (Test-Path $documentShortcut)){
            StartGame
        }
    } 
}

$form.ShowDialog() | Out-Null
# Xinput timer stop
# $timer.Stop() 
