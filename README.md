<h1>DadLauncher</h1>

This script provides a streamlined method for archiving and launching PC games through Playnite, supporting .7z and .bat scripts for linking to external installers (e.g., GOG offline installers).
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

    GameName [version].7z/

Example:

    FlatOut [1.0.0].7z

    The name must match the game shortcut name (excluding version info).

<h3>🗃️ Installation Tracking</h3>

Installed games are tracked via text files located in:

%USERPROFILE%\Documents\DadLauncher\Installed\

Each file is named after the game (e.g., FlatOut.txt) and contains the install path.

The script uses this to determine if the game is already installed and whether to prompt for updates (when a newer version archive is found).

<h3>⚙️ Setup Instructions</h3>
    Compile with Win-PS2EXE (but keep reading before you do)

    Add DadLauncher.exe to Playnite as a custom emulator.

    Set all PC game shortcuts to launch through this emulator.

    Ensure your shortcut files (.lnk) are located in a directory added as an Auto-scan configuration in Playnite.

    Place archives in the designated archive directory, using the proper naming convention.

    Before compiling:
    
    Define your paths (Line 811)
    For now, the script logic assumes a Shortcut target path "D:\Games\PC\GameName\target.exe" and replaces the "D:\Games\PC\" with your desired path.
    This is kind of stupid though so I will "eventually" change this logic "later".
    TODO: Stop using shortcuts to make it easier on everyone
    TODO: Just scan the registry for 7z and 7zG
    My archive folder structure is D:\Games\Archives\GameName\GameName [1.2.3].7z
    TODO: Let the user set their archive top path in the settings
    This assumes playnite is set as a portable install, you may need to change these paths slightly if yours isn't
    TOOD: Just check both paths 

    Run the game from Playnite — the script will guide you through any required installation or updates.

<h3>📬 Notes</h3>

    Ultimately, I made this script for my convenience, changes to this script are solely for myself. 
    However, You are free to use and edit this script as you wish, and feedback is appreciated.
