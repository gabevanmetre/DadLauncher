# Usage: .\HashScript.ps1 -Root "D:\Games\Archives2"

param(
    [string]$Root = 'D:\Games\Archives',
    [string]$SevenZipPath = 'C:\Program Files\7-Zip\7z.exe'
)

# Ensure the Hashes directory exists
$sfvDir = Join-Path $Root "Hashes"
$Log = Join-Path $sfvDir "hash_errors.log"
if (-not (Test-Path $sfvDir)) {
    New-Item -Path $sfvDir -ItemType Directory | Out-Null
}

# Get all .7z files in the specified directory
$archives = Get-ChildItem -Path $Root -Filter '*.7z' -File

foreach ($archive in $archives) {
    $archivePath = $archive.FullName

    $sanitizedName = ($archive.BaseName -replace '[\\\/:*?"<>|]', '_')
    $sfvName = "$sanitizedName.sfv"
    $sfvPath = Join-Path $sfvDir $sfvName

    Write-Host "sfvName: $sfvName`nsfvPath: $sfvPath"

    if (Test-Path $sfvPath) {
        Write-Host "Skipping: $($archive.Name) (already hashed)"
        continue
    }

    Write-Host "Hashing contents of: $($archive.Name)..."

    # Run '7z l -slt' to get detailed listing including CRC hashes
    $output = & "$SevenZipPath" l -slt "$archivePath"

    $sfvLines = @()
    $current = @{}

    foreach ($line in $output) {
        if ($line -eq "") {
            if ($current["Path"] -and $current["CRC"]) {
                $sfvLines += "{0} {1}" -f $current["Path"], $current["CRC"]
            }
            $current = @{}
            continue
        }

        $kv = $line -split " = ", 2
        if ($kv.Count -eq 2) {
            $current[$kv[0].Trim()] = $kv[1].Trim()
        }
    }

    try {
        $sfvLines | Set-Content -LiteralPath $sfvPath -Encoding ASCII
    } catch {
        $errorMessage = @"
[$(Get-Date -Format "u")]
Failed to save SFV file: $sfvPath
Error: $($_.Exception.Message)
--------------------------------------------------
"@
        $errorMessage | Out-File -LiteralPath $Log -Encoding utf8 -Append
    }
}
