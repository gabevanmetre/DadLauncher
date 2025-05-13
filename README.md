<h1>Game Archival & Launch System for Playnite</h1>

This script provides a streamlined method for archiving and launching PC games through Playnite, supporting .7z, .zip, .rar formats, and .bat scripts for linking to external installers (e.g., GOG offline installers).
It is designed for long-term game archival while providing convenient and automated installation and launching.

<h3>🧰 Requirements</h3>

    Playnite

    Archive files named in a specific format (see below)

    Shortcut links for each game (.lnk files)

    The GameLaunch Shortcut.lnk added to Playnite as an emulator

<h3>📁 File & Naming Conventions</h3>

Shortcut Format

Shortcuts must follow this format:

GameName (Optional Version Information).lnk

Example:

    ..\FlatOut.lnk
    ..\FlatOut (Config).lnk

These allow grouping of launchers (e.g., game + config) under the same title in Playnite.

Archive Format

Archives should be named as:

    GameName [version].7z/.zip/.rar

Example:

    FlatOut [1.0.0].7z

    The name must match the game shortcut name (excluding version info).

<h3>🗃️ Installation Tracking</h3>

Installed games are tracked via text files located in:

%USERPROFILE%\Documents\DadLauncher\Installed\

Each file is named after the game (e.g., FlatOut.txt) and contains the install path.

The script uses this to determine if the game is already installed and whether to prompt for updates (when a newer version archive is found).

<h3>⚙️ Setup Instructions</h3>

    Add GameLaunch Shortcut.lnk to Playnite as a custom emulator.

    Set all PC game shortcuts to launch through this emulator.

    Ensure your shortcut files (.lnk) are located in a directory added as an Auto-scan configuration in Playnite.

    Place archives in the designated archive directory, using the proper naming convention.

    In GameLaunch.ps1, the path to your archives will need to be substituted:

    Line 9:     $archive                  = "D:\Games\Archives\$gameName"
    Line 469:   $archivePathBat = Get-ChildItem -Path "D:\\Games\\Archives" -Filter "$gameName*.bat"
    Line 470:   $archivePath7z = Get-ChildItem -Path "D:\\Games\\Archives" -Filter "$gameName*.7z"

    This path will need to be changed to your games install path:

    Line 310:   $exePath = $exePath -replace [regex]::Escape("D:\Games\PC\"), $global:DefaultInstallPath

    Run the game from Playnite — the script will guide you through any required installation or updates.

To enable debug output:

    Open GameLaunch.bat in a text editor
    Uncomment (remove REM from) the debug line to display the PowerShell window

<h3>📬 Notes</h3>

    I made this script for my convenience, changes to this script are solely for myself. 
    You are free to use and edit this script as you wish, and feedback is appreciated.
