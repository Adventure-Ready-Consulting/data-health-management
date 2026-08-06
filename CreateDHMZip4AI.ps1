# CreateDHMZip4AI.ps1
# Creates a ZIP containing the Salesforce source directories required for
# Data Health Management: manifest and src.

[CmdletBinding()]
param(
    [string]$Root = "C:\repo\data-health-management"
)

$ErrorActionPreference = "Stop"

$requiredDirectories = @(
    "manifest",
    "src"
)

$packageXml = Join-Path $Root "manifest\package.xml"

if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
    throw "Repository root was not found: $Root"
}

foreach ($directory in $requiredDirectories) {
    $fullPath = Join-Path $Root $directory

    if (-not (Test-Path -LiteralPath $fullPath -PathType Container)) {
        throw "Required directory was not found: $fullPath"
    }
}

if (-not (Test-Path -LiteralPath $packageXml -PathType Leaf)) {
    throw "Required manifest file was not found: $packageXml"
}

# Remove ZIP files previously created by this script.
Get-ChildItem -LiteralPath $Root -Filter "DataHealthManagementSource_*.zip" -File -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction SilentlyContinue

$tempFolder = Join-Path $env:TEMP ("DataHealthManagementSource_" + [guid]::NewGuid().ToString("N"))

try {
    New-Item -ItemType Directory -Path $tempFolder -Force | Out-Null

    foreach ($directory in $requiredDirectories) {
        $sourcePath = Join-Path $Root $directory
        $destinationPath = Join-Path $tempFolder $directory

        Copy-Item `
            -LiteralPath $sourcePath `
            -Destination $destinationPath `
            -Recurse `
            -Force
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $zipFile = Join-Path $Root "DataHealthManagementSource_$timestamp.zip"

    Compress-Archive `
        -Path (Join-Path $tempFolder "*") `
        -DestinationPath $zipFile `
        -CompressionLevel Optimal `
        -Force

    Write-Host ""
    Write-Host "ZIP created successfully:"
    Write-Host $zipFile
    Write-Host ""
    Write-Host "Included directories:"
    Write-Host "  manifest"
    Write-Host "  src"
}
finally {
    if (Test-Path -LiteralPath $tempFolder) {
        Remove-Item -LiteralPath $tempFolder -Recurse -Force -ErrorAction SilentlyContinue
    }
}
