$Host.UI.RawUI.WindowTitle = "Game Comparator"

# Set the paths to your folders
$gamesFolder = "D:\Games\PC"
$shortcutsFolder = "D:\Games\Shortcuts"
$archivesFolder = "D:\Games\Archives"

# Get a list of game folders and archives
$gameFolders = Get-ChildItem -Path $gamesFolder -Directory | Select-Object -ExpandProperty Name
$archives = Get-ChildItem -Path $archivesFolder -File | ForEach-Object {
    $_.BaseName -replace '\s*\[.*?\]$', '' -replace '\s*\(.*?\)$', '' -replace '\s*$'
}

# Combine and sort the lists, then remove duplicates
$games = ($gameFolders + $archives) | Sort-Object -Unique

# Get a list of shortcut names without extensions and with parentheses removed
$shortcuts = Get-ChildItem -Path $shortcutsFolder -File | ForEach-Object {
    $_.BaseName -replace '\s*\[.*?\]$', '' -replace '\s*\(.*?\)$', '' -replace '\s*$'
}

# Initialize an empty list to store games without shortcuts
$gamesWithoutShortcuts = @()

# Loop through each game and check if it has a corresponding shortcut
foreach ($game in $games) {
    if ($shortcuts -notcontains $game) {
        $gamesWithoutShortcuts += $game
    }
}

# Set the output file path
$outputFile = "GamesWithoutShortcuts.txt"

# Output the list of games without shortcuts to a text file
$gamesWithoutShortcuts | Out-File -FilePath $outputFile

Write-Host "List of games without shortcuts has been saved to $outputFile"
