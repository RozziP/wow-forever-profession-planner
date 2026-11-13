[CmdletBinding()]
param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '../dist'),
    [string]$Tag
)

$ErrorActionPreference = 'Stop'
# Keep the installed folder and TOC names so WoW can load existing saved settings.
$addonName = 'ForeverProfessionPlanner'
$addonDirectory = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../addon/$addonName")).Path
$tocName = "$addonName.toc"
$foreverTocName = "${addonName}_Forever.toc"
$tocPath = Join-Path $addonDirectory $tocName
$toc = Get-Content -LiteralPath $tocPath -Raw

$version = [regex]::Match($toc, '(?m)^## Version:[ \t]*(\d+\.\d+\.\d+)[ \t]*\r?$').Groups[1].Value
if (!$version) {
    throw "Expected a numeric major.minor.patch version in $tocName."
}
if ($Tag -and $Tag -cne "v$version") {
    throw "Release tag '$Tag' must match TOC version 'v$version'."
}
if ($toc -notmatch '(?m)^## Interface:[ \t]*16\d{3}[ \t]*\r?$') {
    throw "Expected a WoW Forever interface version in $tocName."
}

$addonFiles = Get-ChildItem -LiteralPath $addonDirectory -File -Recurse
$relativePaths = @($addonFiles | ForEach-Object {
    [IO.Path]::GetRelativePath($addonDirectory, $_.FullName).Replace('\', '/')
})
foreach ($line in ($toc -split '\r?\n')) {
    $path = $line.Trim().Replace('\', '/')
    if ($path -and !$path.StartsWith('#') -and $relativePaths -cnotcontains $path) {
        throw "Missing TOC file '$path' in $addonName."
    }
}

$output = (New-Item -ItemType Directory -Path $OutputDirectory -Force).FullName
$zipPath = Join-Path $output "ForeverProfessionTrainer-$version-forever.zip"
$archiveFile = [IO.File]::Open($zipPath, [IO.FileMode]::Create)
try {
    $archive = [IO.Compression.ZipArchive]::new($archiveFile, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($file in $addonFiles) {
            $relativePath = [IO.Path]::GetRelativePath($addonDirectory, $file.FullName).Replace('\', '/')
            if ($relativePath -ceq $tocName) {
                $relativePath = $foreverTocName
            }
            [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $archive, $file.FullName, "$addonName/$relativePath", [IO.Compression.CompressionLevel]::Optimal
            )
        }
    } finally {
        $archive.Dispose()
    }
} finally {
    $archiveFile.Dispose()
}
Write-Output $zipPath
