# Set-PSDebug -Trace 2
# Gabriel Van Metre
$Host.UI.RawUI.WindowTitle = "DadLauncher Debug Console"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

Add-Type -Path "Plugins\SharpDX.dll"
Add-Type -Path "Plugins\SharpDX.XInput.dll"
Add-Type -Path "Plugins\SharpDXHelperLibrary.dll"
Unblock-File -Path "Plugins\Xceed.Wpf.Toolkit.dll"
Add-Type -Path "Plugins\Xceed.Wpf.Toolkit.dll"
Unblock-File -Path "Plugins\BetterFolderBrowser.dll"
Add-Type -Path "Plugins\BetterFolderBrowser.dll"

# Define Win32 API functions for showing and hiding the console
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class Win32 {
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@
# Define API functions for Aero settings
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

# Set console size to 120 columns and 40 lines
# mode con: cols=120 lines=40

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
. "$ScriptDir\Functions\Menus.ps1"
. "$ScriptDir\Functions\PostInstall.ps1"

# Constants
$SW_HIDE                    = 0
$SW_SHOW                    = 5
$SW_RESTORE                 = 9
$7z                         = "C:\Program Files\7-Zip\7z.exe"
$7zG                        = "C:\Program Files\7-Zip\7zG.exe"
$scriptPath                 = split-path -parent $MyInvocation.MyCommand.Definition
$iconPath                   = Join-Path $scriptPath 'icon.ico'
$baseShortcutPath           = "D:\Games\PC\"
$dadLauncherFolder          = "$env:USERPROFILE\Documents\DadLauncher"
$documentShortcutFolder     = "$dadLauncherFolder\Shortcuts\"
$archivePath                = "D:\Games\Archives"
$xamlPath                   = "Views\GameLaunchMenu.xaml"
# Store the console window handle
$consolePtr = [Win32]::GetConsoleWindow()
Write-Host "`n-------------------`nDadLauncher Console`n-------------------`n"

if ($args.Length -eq 0) {
    Write-Host "Please provide a path as an argument."
    Read-Host "Press Enter to continue..."
    exit 1
}

if (-not (Test-Path $7z)) {
    Write-Host "7z not found, please install 7z."
    Read-Host "Press Enter to continue..."
    exit 1
}

$shortcut = $args[0]
$databaseID = $args[1]
$playniteDir = $args[2]
Write-Host "shortcut: $shortcut"
$logoPath = Join-Path $playniteDir "ExtraMetadata\games\$databaseID\Logo.png"
$imagesPath = Join-Path $playniteDir "library\files\$databaseID\"
Write-Host "logoPath: $logoPath"
Write-Host "imagesPath: $imagesPath"
$wideImagePath = Get-WideImage
Write-Host "wideImagePath: $wideImagePath"
$originalShortcut = (New-Object -ComObject WScript.Shell).CreateShortcut($shortcut)

$exeArgs = $originalShortcut.Arguments

# I tried to combine this and it doesn't work
$gameNameOriginal = [System.IO.Path]::GetFileNameWithoutExtension($shortcut)
$documentShortcut = -join("$documentShortcutFolder", "$gameNameOriginal", ".lnk")
$gameName = $gameNameOriginal -replace '\(.*\)', ''
$gameName = $gameName.TrimEnd()

Write-Host "documentShortcut: $documentShortcut"
Write-Host "gameName: $gameName"

# Settings Folder Setup
if (-not (Test-Path -Path $dadLauncherFolder)) {
	New-Item -Path $dadLauncherFolder -ItemType Directory
	Write-Host "Created $dadLauncherFolder."
} else {
	Write-Host "$dadLauncherFolder already exists." -ForegroundColor Green
}

$installedFolder = Join-Path -Path $dadLauncherFolder -ChildPath "Installed"

if (-not (Test-Path -Path $installedFolder)) {
	New-Item -Path $installedFolder -ItemType Directory
	Write-Host "Created Installed subfolder."
}

# Settings Block
$global:settingsFile = Join-Path -Path $dadLauncherFolder -ChildPath "settings.ini"
Write-Host "settingsFile: $settingsFile"
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
    Write-Host "IgnoreLanWarning empty or invalid, resetting."
    $invalidSettings = $true
    [bool]::Parse($defaultSettings.IgnoreLanWarning)
}


$global:DesktopShortcut = if ($settings.DesktopShortcut -match '^(true|false)$') {
    [bool]::Parse($settings.DesktopShortcut)
} else {
    Write-Host "DesktopShortcut empty or invalid, resetting."
    $invalidSettings = $true
    [bool]::Parse($defaultSettings.DesktopShortcut)
}

Write-Host "Checking DefaultInstallPath: '$($settings.DefaultInstallPath)'"
$installPath = $settings.DefaultInstallPath.Trim()
Write-Host "Checking DefaultInstallPath: '$installPath'"

$global:DefaultInstallPath = if (
    -not $installPath -or
    -not (Test-WriteablePath $installPath)
) {
    Write-Host "DefaultInstallPath is invalid or not writeable. Resetting to default."
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
    Write-Host "Settings.ini updated with corrected values."
}

# Output final values
Write-Host "IgnoreLanWarning: $global:IgnoreLanWarning"
Write-Host "DesktopShortcut: $global:DesktopShortcut"
Write-Host "DefaultInstallPath: $global:DefaultInstallPath"

$archivePathNoExt = "$archivePath\$gameName"
$archivePath = "$archivePath\$gameName"
Write-Host "archivePath: $archivePath "

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
	Read-Host "Press Enter to continue..."

	exit 1
}

if ($archive -match "\[(\d+(\.\d+)*)\]") {
	$global:archiveVersion = $matches[1]  # This will capture the version from the match
} else {
	$global:archiveVersion = 0
}
Write-Host "Archive Found: $archive"
Write-Host "Archive Version: $archiveVersion"
Write-Host "Archive Type: $Bat7z"
Write-Host "shortcut: $shortcut"


# If the shortcut is usable, it's installed on my D:\Games\PC
if (Test-Path $shortcut) {
    $global:originalShortcutPath = $originalShortcut.TargetPath

    if (Test-Path $originalShortcutPath) {
        Write-Host "Game is on LAN path: $originalShortcutPath"
        $global:isLAN = 1
    } else {
        Write-Host "Not Installed at D:\Games\PC\"
    }
} else {

    Write-Warning "Invalid argument passed."
    timeout 20
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
    Write-Host "Original Size: $readableSize"
    $global:requiredText = "Required Space: $readableSize"
} else {
    Write-Host "Last line did not match expected format:"
    Write-Host $lastLine
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
	Write-Host "Installed Path: $installedPath"
	Write-Host "Installed Version: $installedVersion"
    $exePath = $installedPath
    Write-Host "$exePath"

    if (-not $installedVersion) {
        $installedVersion = "0.0"
    }
    if ($archiveVersion -and ([version]$archiveVersion) -gt ([version]$installedVersion)) {
        $newVersionNumber = $archiveVersion
        Write-Host "Archive version $newVersionNumber is more recent than installed version $installedVersion"
    } else {
        try{
            StartGame
        }catch{
            Write-Warning "StartGame attempted but no usable .exe was found."
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
$consoleButton                = $form.FindName("TitleButtonConsole")
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
    Write-Host "Is this thing on"
    $settingsBorder.Visibility = "Collapsed"
})

$settingsCloseButton.Add_Click({
    Write-Host "Is this thing on"
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

# Inputs
$form.Add_KeyDown({if ($_.Key -eq "Escape") {$form.Close()}})
$form.Add_KeyDown({
    if ($_.Key -eq "F5") {
        Show-ConsoleWindow
    }
    elseif ($_.Key -eq "F4") {
        Hide-ConsoleWindow
    }
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

$consoleButton.Add_Click({
    Show-ConsoleWindow
    Clear-Focus
})

$closeButton.Add_Click({
    $form.Close()
})

$settingsButton.Add_Click({
    ToggleSettingsMenu
    Write-Host "Settings Menu Button Clicked"
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
        Write-Warning "Error Loading Background: $_"
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
        Menu7zInstall
    } 
}

$form.ShowDialog() | Out-Null
# Xinput timer stop
# $timer.Stop() 
