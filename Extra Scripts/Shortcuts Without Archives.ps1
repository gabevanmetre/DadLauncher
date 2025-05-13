$Host.UI.RawUI.WindowTitle = "Game Comparator - Shortcuts Without Archives"

# Set the paths to your folders
$shortcutsFolder = "D:\Games\Shortcuts"
$archivesFolder = "D:\Games\Archives"

# Get a list of archives (archive names without extensions, parentheses, and version numbers)
$archives = Get-ChildItem -Path $archivesFolder -File | ForEach-Object {
    $_.BaseName -replace '\s*\[.*?\]$', '' -replace '\s*\(.*?\)$', '' -replace '\s*$'
}

# Get a list of shortcut names without extensions and parentheses
$shortcuts = Get-ChildItem -Path $shortcutsFolder -File | ForEach-Object {
    $_.BaseName -replace '\s*\[.*?\]$', '' -replace '\s*\(.*?\)$', '' -replace '\s*$'
}

# Initialize an empty list to store shortcuts without archives
$shortcutsWithoutArchives = @()

# Loop through each shortcut and check if it has a corresponding archive
foreach ($shortcut in $shortcuts) {
    if ($archives -notcontains $shortcut) {
        $shortcutsWithoutArchives += $shortcut
    }
}

# Set the output file path
$outputFile = "ShortcutsWithoutArchives.txt"

# Output the list of shortcuts without archives to a text file
$shortcutsWithoutArchives | Out-File -FilePath $outputFile

Write-Host "List of shortcuts without archives has been saved to $outputFile"
