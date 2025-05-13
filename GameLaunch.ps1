$Host.UI.RawUI.WindowTitle = "Dad Game Launcher"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

function MenuBuild {
    $xamlPath                 = "Views\GameLaunchMenu.xaml"
    $archive                  = "D:\Games\Archives\$gameName"
    $form                     = [Windows.Markup.XamlReader]::Load([System.Xml.XmlReader]::Create($xamlPath))
    $form.DataContext         = [PSCustomObject]@{ Archive = $archive }
    $minimizeButton           = $form.FindName("TitleButtonMinimize")
    $closeButton              = $form.FindName("TitleButtonClose")
    $settingsButton           = $form.FindName("BottomSettingsButton")
    $cancelButton             = $form.FindName("CancelButton")
    $staticLabel              = $form.FindName("StaticLabel")
    $hiddenButtonYes          = $form.FindName("HiddenButtonYes")
    $hiddenButtonInstallLocal = $form.FindName("HiddenButtonInstallLocal")
    $hiddenButtonPlay         = $form.FindName("HiddenButtonPlay")
    $installButton            = $form.FindName("InstallButton")
    $choosePathButton         = $form.FindName("ChoosePathButton")

    $staticLabel.Visibility   = "Visible"
	$installButton.Content    = "Install to $global:DefaultInstallPath"
    $cancelHandlerDefault     = {Exit 1}

    $cancelButton.Add_Click($cancelHandlerDefault)

    $form.Add_MouseLeftButtonDown({
        $form.DragMove()
    })

    $minimizeButton.Add_Click({
        $form.WindowState = 'Minimized'
    })

    $closeButton.Add_Click({
        $form.Close()
    })

    $settingsButton.Add_Click({
        Show-SettingsMenu $staticLabel $installButton
    })

    if ($global:versionNumber) {
        MenuNewVersion
    } elseif ($isLAN -eq 1) {
        if ($global:IgnoreLanWarning -eq $true) {
            StartGame
        } else {
            MenuLANShortcut
        }
    } else {
        ArchiveBatOr7z
    }
    $form.ShowDialog() | Out-Null
}

function Show-SettingsMenu {
    param(
        [Parameter(Mandatory=$true)]
        [System.Windows.Controls.TextBlock]$staticLabel,

        [Parameter(Mandatory=$true)]
        [System.Windows.Controls.Button]$installButton
    )
    $xamlPath       = "Views\SettingsMenu.xaml"
    $reader         = [System.Xml.XmlReader]::Create($xamlPath)
    $settingsWindow = [Windows.Markup.XamlReader]::Load($reader)
    $settingsFile   = $global:settingsFile

    $settingsWindow.Add_MouseLeftButtonDown({
        $settingsWindow.DragMove()
    })
    $saveButton           = $settingsWindow.FindName("SaveSettingsButton")
    $cancelButton         = $settingsWindow.FindName("CancelButton")
    $ignoreLanCheck       = $settingsWindow.FindName("LanCheckBox")
    $desktopShortcutCheck = $settingsWindow.FindName("DesktopShortcutCheckBox")
    $installPathField     = $settingsWindow.FindName("InstallPathField")
    $installPathButton    = $settingsWindow.FindName("InstallPathButton")
    $closeButton          = $settingsWindow.FindName("TitleButtonClose")

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
                "DefaultInstallPath"      { 
                    $installPathField.Text = $entry.Value
                    $global:DefaultInstallPath = $entry.Value
                }
            }
        }
    }

    # Folder browser for install path
    $installPathButton.Add_Click({
        if (Show-FolderPicker) {
            $installPathField.Text = $global:DefaultInstallPath
        }
    })

    $saveButton.Add_Click({
        $global:IgnoreLanWarning   = $ignoreLanCheck.IsChecked
        $global:DesktopShortcut    = $desktopShortcutCheck.IsChecked
        $global:DefaultInstallPath = Normalize-PathToDoubleBackslash $installPathField.Text
        WriteSettingsFile
        $staticLabel.Text          = "Archive found for $gameName. Install to $defaultinstallpath, to a different path, or cancel?"
        $installButton.Content     = "Install to $defaultinstallpath"
        $settingsWindow.Close()
    })

    $cancelButton.Add_Click({
        $settingsWindow.Close()
    })

    $closeButton.Add_Click({
        $settingsWindow.Close()
    })

    $settingsWindow.ShowDialog() | Out-Null
}

function Normalize-PathToDoubleBackslash {
    param (
        [string]$inputPath
    )
    $cleaned = $inputPath -replace '\s', ''
    $cleaned = $cleaned -replace '\\+', '\'
    $cleaned = $cleaned.TrimEnd('\') + '\'

    return $cleaned
}

function Get-FolderFromDialog {
    Unblock-File -Path "PLugins\BetterFolderBrowser.dll"
    Add-Type -Path "Plugins\BetterFolderBrowser.dll"
    $fb             = New-Object WK.Libraries.BetterFolderBrowserNS.BetterFolderBrowser
    $fb.Title       = "Select a Custom Installation Folder"
    $fb.RootFolder  = $global:DefaultInstallPath
    $fb.Multiselect = $false
    return $fb
}
function Show-FolderPicker {
    $folderBrowser = Get-FolderFromDialog
    if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $global:DefaultInstallPath = $folderBrowser.SelectedFolder
        if ($global:DefaultInstallPath[-1] -ne '\') {
            $global:DefaultInstallPath += '\'
        }
        Write-Host "Selected path: $global:DefaultInstallPath"
        return $true
    } else {
        Write-Host "Folder selection cancelled."
        return $false
    }
}

function Handle-CustomPathSelection {
    param (
        [switch]$ExtractArchive
    )

    if (Show-FolderPicker) {
        if ($ExtractArchive) {
            $7zipProcess = Start-Process -FilePath "C:\Program Files\7-Zip\7zG.exe" `
                -ArgumentList @('x', "`"$global:archive`"", "-o$global:DefaultInstallPath") `
                -PassThru -Wait

            if ($7zipProcess.ExitCode -eq 0) {
                CreateTxt
                ChangeMenuLaunchGameNewPath
            } else {
                Write-Host "7zip extraction failed or cancelled."
            }
        } else {
            CreateTxt
        }
    }
}

function MenuRemove {
    $cancelButton.Content = "No"
    $installButton.Visibility = "Collapsed"
    $choosePathButton.Visibility = "Collapsed"
    $hiddenButtonYes.Visibility = "Visible"
    $staticLabel.Visibility = "Visible"
}

function MenuLANShortcut {
    $staticLabel.Text = "$gameName is installed on the LAN and may run slowly. Do you want to play from the network or install locally?"
    $choosePathButton.Visibility = "Collapsed"
    $installButton.Visibility = "Collapsed"
    $hiddenButtonPlay.Visibility = "Visible"
    $hiddenButtonPlay.Add_Click({
        StartGame
        exit 1
    })
    $hiddenButtonInstallLocal.Visibility = "Visible"
    $hiddenButtonInstallLocal.Add_Click({ ArchiveBatOr7z })
}
function MenuNewVersion {
	$staticLabel.Text = "A new version of $gameName is available. Do you want to install the new version?"
	$hiddenButtonYes.Visibility = "Visible"
	$hiddenButtonYes.Add_Click({ Menu7zInstall })
	$cancelButton.Content = "No"
    $choosePathButton.Visibility = "Collapsed"
    $installButton.Visibility = "Collapsed"
    $hiddenButtonPlay.Visibility = "Visible"
    $hiddenButtonPlay.Add_Click({
        StartGame
        exit 1
    })
}
function MenuInstaller {
    $staticLabel.Text = "This script needs to launch an external installer. Do you want to continue?"
    $hiddenButtonInstallLocal.Visibility = "Collapsed"
    $choosePathButton.Visibility = "Collapsed"
    $installButton.Visibility = "Collapsed"
	$hiddenButtonYes.Visibility = "Visible"
	$cancelButton.Content = "No"	
    $hiddenButtonYes.Add_Click({
        Start-Process $archive
        exit 1
    })
}

function Menu7zInstall {
    $staticLabel.Text =  "Archive found for $gameName. Install to $defaultinstallpath, to a different path, or cancel?"
    $hiddenButtonPlay.Visibility = "Collapsed"
    $hiddenButtonInstallLocal.Visibility = "Collapsed"
	$hiddenButtonYes.Visibility = "Collapsed"
	$cancelButton.Content = "Cancel"
    $installButton.Visibility = "Visible"
    $installButton.Add_Click({
        $global:exePath = $originalShortcut.TargetPath
        $7zipProcess = Start-Process -FilePath "C:\Program Files\7-Zip\7zG.exe" -ArgumentList @('x', "`"$global:archive`"", "-o$global:DefaultInstallPath") -PassThru -Wait

        if ($7zipProcess.ExitCode -eq 0) {		
            CreateTxt
            ChangeMenuLaunchGame
        } else {
            Write-Host "7zip extraction failed or cancelled."
        }
    })

    $choosePathButton.Visibility = "Visible"
    $choosePathButton.Add_Click({Handle-CustomPathSelection -ExtractArchive})
}
function ArchiveBatOr7z {
    if ($global:Bat7z -eq "Bat") {
        MenuInstaller
    } 
	else {
        Menu7zInstall
    } 
}
function ChangeMenuLaunchGame {
    param ([string]$exePath)
    MenuRemove
    $StaticLabel.Text = "Do you want to launch the game?"
    $hiddenButtonYes.Add_Click({
        StartGame
        exit 1
    })
    $cancelButton.Add_Click({
        exit 1
    })
}
function ChangeMenuLaunchGameNewPath {
    param ([string]$exePath)
    MenuRemove
    $StaticLabel.Text = "Change your default path to $global:DefaultInstallPath`?"
    $hiddenButtonYes.Add_Click({
        if (-not (Test-Path -Path $global:settingsFile)) {
            Write-Host "settings.ini not found. Cannot update DefaultInstallPath."
            return
        }
        WriteSettingsFile
        Write-Host "Updated DefaultInstallPath to $global:DefaultInstallPath in settings.ini"
        ChangeMenuLaunchGame
    })
    $cancelButton.Remove_Click($cancelHandlerDefault)  # Remove old exit handler
    $cancelButton.Add_Click({
        ChangeMenuLaunchGame
    })
}
function WriteSettingsFile{
    $escapedInstallPath = Normalize-PathToDoubleBackslash $global:DefaultInstallPath
    $settingsContent = @"
IgnoreLanWarning=$global:IgnoreLanWarning
DesktopShortcut=$global:DesktopShortcut
DefaultInstallPath=$escapedInstallPath
"@
    $settingsContent | Out-File -FilePath $global:settingsFile -Encoding UTF8
    Write-Host "Updated settings.ini file with new values."
}

function CreateTxt {
    $WshShell = New-Object -comObject WScript.Shell
    $exePath = $originalShortcut.TargetPath

    $exePath = $exePath -replace [regex]::Escape("D:\Games\PC\"), $global:DefaultInstallPath
	
	$gameTxtFile = "$env:USERPROFILE\\Documents\\DadLauncher\\Installed\\$gameName.txt"

	$txtContent = @()
	$txtContent += "InstalledPath=$exePath"
	if ($archiveVersion) {
		$txtContent += "Version=$archiveVersion"
	} else {
		$txtContent += "Version=0.0"
	}
	$txtContent | Set-Content -Path $gameTxtFile
   	Write-Host "Installed to $exePath"
    if ($global:DesktopShortcut -eq $true) {
		$desktopPath = [System.Environment]::GetFolderPath('Desktop')
		$desktopShortcutPath = Join-Path -Path $desktopPath -ChildPath "$gameName.lnk"

		if (Test-Path $desktopShortcutPath) {
			Remove-Item -Path $desktopShortcutPath
		}

		try {
			$shortcut = $WshShell.CreateShortcut($desktopShortcutPath)

			$shortcut.TargetPath = $exePath
			$shortcut.WorkingDirectory = [System.IO.Path]::GetDirectoryName($exePath)

			$shortcut.IconLocation = "$exePath,0"

			$shortcut.Save()
			Write-Host "Created Desktop shortcut: $desktopShortcutPath"
		} catch {
			Write-Host "Error creating shortcut: $_"
		}
    }
	
    $global:exePath = $exePath
}

function Import-IniFile {
    param (
        [string]$Path
    )

    $ini = @{}
    Get-Content $Path | ForEach-Object {
        $_ = $_.Trim()
        if ($_ -match '^\s*#') { return }       # Skip comments
        if ($_ -match '^\s*$') { return }       # Skip empty lines
        if ($_ -match '^(.*?)\s*=\s*(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            $ini[$key] = $value
        }
    }
    return $ini
}

function StartGame {
    if (-not $originalShortcut.Arguments) {
        Write-Host "No arguments passed. Starting the game without arguments."
        Start-Process -FilePath $exePath -WorkingDirectory (Split-Path $exePath -Parent)
    } else {
        Write-Host "Starting the process with arguments: $originalShortcut.Arguments"
        Start-Process -FilePath $exePath -ArgumentList $originalShortcut.Arguments -WorkingDirectory (Split-Path $exePath -Parent)
    }
	timeout 1
    exit 1
}

##

$dadLauncherFolder = "$env:USERPROFILE\Documents\DadLauncher"

if ($args.Length -eq 0) {
    Write-Host "Please provide a path as an argument."
    Read-Host "Press Enter to continue..."
    exit 1
}
$shortcut = $args[0]
$originalShortcut = (New-Object -ComObject WScript.Shell).CreateShortcut($shortcut)

# $gameName = [System.IO.Path]::GetFileNameWithoutExtension($shortcut) -replace '\(.*\)', '' -TrimEnd()
# Doesn't work don't try it

$gameName = [System.IO.Path]::GetFileNameWithoutExtension($shortcut)
$gameName = $gameName -replace '\(.*\)', ''
$gameName = $gameName.TrimEnd()


if (-not (Test-Path -Path $dadLauncherFolder)) {
	New-Item -Path $dadLauncherFolder -ItemType Directory
	Write-Host "Created $dadLauncherFolder."
} else {
	Write-Host "$dadLauncherFolder already exists."
}
$installedFolder = Join-Path -Path $dadLauncherFolder -ChildPath "Installed"
if (-not (Test-Path -Path $installedFolder)) {
	New-Item -Path $installedFolder -ItemType Directory
	Write-Host "Created Installed subfolder."
} else {
	Write-Host "Installed subfolder already exists."
}
$global:settingsFile = Join-Path -Path $dadLauncherFolder -ChildPath "settings.ini"

$defaultSettings = @{
    IgnoreLanWarning     = 'false'
    DesktopShortcut      = 'true'
    DefaultInstallPath   = 'C:\\Games\\'
}
$settings = Import-IniFile -Path $global:settingsFile
$settings["InstallDir"]

$global:IgnoreLanWarning = if (($defaultSettings.IgnoreLanWarning -eq $null) -or
                               ($defaultSettings.IgnoreLanWarning -notmatch '^(true|false)$')) {
    Write-Host "IgnoreLanWarning empty or invalid, resetting."
    $defaultSettings.IgnoreLanWarning
    $invalidSettings = $true
} else {
    [bool]::Parse($settings.IgnoreLanWarning)
}

$global:DesktopShortcut = if (($defaultSettings.DesktopShortcut -eq $null) -or
                              ($defaultSettings.DesktopShortcut -notmatch '^(true|false)$')) {
    Write-Host "DesktopShortcut empty or invalid, resetting."                            
    $defaultSettings.DesktopShortcut
    $invalidSettings = $true
} else {
    [bool]::Parse($settings.DesktopShortcut)
}

$global:DefaultInstallPath = if (($defaultSettings.DefaultInstallPath -eq $null) -or
                                 (-not (Test-Path -Path $defaultSettings.DefaultInstallPath))) {
    # Debugging info
    if ($global:DefaultInstallPath -eq $null) {
        Write-Host "DefaultInstallPath is null or not set."
    } elseif (-not (Test-Path -Path $defaultSettings.DefaultInstallPath)) {
        Write-Host "DefaultInstallPath exists but is not a valid path."
    }
    # Resetting to default
    Write-Host "DefaultInstallPath empty or invalid, resetting."
    $invalidSettings = $true
    $defaultSettings.DefaultInstallPath
} else {
    $settings.DefaultInstallPath
}

if ($invalidSettings -eq $true) {
	$defaultSettings = @"
IgnoreLanWarning=$global:IgnoreLanWarning
DesktopShortcut=$global:DesktopShortcut
DefaultInstallPath=$global:DefaultInstallPath
"@
	$defaultSettings | Out-File -FilePath $global:settingsFile -Encoding UTF8
	Write-Host "Settings.ini saved to $global:settingsFile"
}
Write-Host "IgnoreLanWarning: $global:IgnoreLanWarning"
Write-Host "DesktopShortcut: $global:DesktopShortcut"
Write-Host "DefaultInstallPath: $global:DefaultInstallPath"
$archivePathBat = Get-ChildItem -Path "D:\\Games\\Archives" -Filter "$gameName*.bat"
$archivePath7z = Get-ChildItem -Path "D:\\Games\\Archives" -Filter "$gameName*.7z"

if ($archivePathBat) {
	$global:archive = $archivePathBat.FullName
	$global:Bat7z = "Bat"
} elseif ($archivePath7z) {
	$global:archive = $archivePath7z.FullName
	$global:Bat7z = "7z"
} else {
	Write-Host "Archive not found: $archive"
	Read-Host "Press Enter to continue..."
	exit 1
}
if ($global:archive -match "\[(\d+(\.\d+)*)\]") {
	$archiveVersion = $matches[1]  # This will capture the version from the match
} else {
	$archiveVersion = 0
}
Write-Host "Archive Version: $archiveVersion
Archive Type: $global:Bat7z"


if (Test-Path $shortcut) {
    $global:exePath = $originalShortcut.TargetPath

    if (Test-Path $global:exePath) {
        Write-Host "Game is on LAN path: $global:exePath"
        $global:isLAN = 1
    } else {
        Write-Host "The executable does not exist."
    }
} else {
    Write-Host "Invalid argument passed."
    exit 1
}

$gameTxtFile = "$env:USERPROFILE\Documents\DadLauncher\Installed\$gameName.txt"
if (Test-Path -Path $gameTxtFile) {
	$txtFileSettings = @{}
	Get-Content -Path $gameTxtFile | ForEach-Object {
		if ($_ -match '^(.*?)=(.*)$') {
			$txtFileSettings[$matches[1].Trim()] = $matches[2].Trim()
		}
	}
	$global:installedPath = $txtFileSettings["InstalledPath"]
	$global:localVersion = $txtFileSettings["Version"]
	Write-Host "Installed Path: $global:installedPath"
	Write-Host "Installed Version: $global:localVersion"
    $exePath = $global:installedPath
    if (Test-Path $exePath) {
       if ($global:localVersion) {
             if ($archiveVersion -and ([version]$archiveVersion) -gt ([version]$global:localVersion)) {
				$global:versionNumber = $archiveVersion
				Write-Host "Archive version $global:versionNumber is more recent than installed version $global:localVersion"
			} else {
				Write-Host "Using local install shortcut: $env:USERPROFILE\Documents\DadLauncher\Installed\$gameName.txt"
				StartGame
			}		
        }
    } else {
        Remove-Item -Path "$env:USERPROFILE\Documents\DadLauncher\Installed\$gameName.txt"
    }
}

MenuBuild