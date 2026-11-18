#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^v[0-9]+\.[0-9]+\.[0-9]+$')][string]$Tag,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$config = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'curseforge.json') -Raw | ConvertFrom-Json
$releaseJson = & gh release view $Tag --repo $config.repository --json tagName,isDraft,isPrerelease,body,assets
if ($LASTEXITCODE -ne 0) { throw 'Could not read the GitHub release.' }
$release = $releaseJson | ConvertFrom-Json
if ($release.isDraft -or $release.isPrerelease -or $release.tagName -cne $Tag) {
    throw 'Only a published stable release with the requested tag can be uploaded.'
}
$version = $Tag.Substring(1)
$assetName = "$($config.assetPrefix)-$version-forever.zip"
$assets = @($release.assets | Where-Object name -CEQ $assetName)
if ($assets.Count -ne 1) { throw "Expected exactly one release asset named $assetName." }
if ([string]::IsNullOrWhiteSpace($release.body)) { throw 'Add release notes on GitHub before uploading to CurseForge.' }

$tempPath = Join-Path ([IO.Path]::GetTempPath()) ('curseforge-' + [guid]::NewGuid())
[IO.Directory]::CreateDirectory($tempPath) | Out-Null
try {
    & gh release download $Tag --repo $config.repository --pattern $assetName --dir $tempPath
    if ($LASTEXITCODE -ne 0) { throw 'Could not download the GitHub release asset.' }
    $zipPath = Join-Path $tempPath $assetName
    $zip = [IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        $entries = @($zip.Entries | Where-Object { $_.Name })
        foreach ($entry in $entries) {
            if (-not $entry.FullName.StartsWith("$($config.addonFolder)/", [StringComparison]::Ordinal) -or
                $entry.FullName -match '(^|/)\.\.(/|$)|\\') {
                throw "Unexpected archive path: $($entry.FullName)"
            }
        }
        $tocs = @($entries | Where-Object FullName -Match '\.toc$')
        if ($tocs.Count -eq 0) { throw 'Release ZIP contains no TOC.' }
        $interfaces = @()
        foreach ($toc in $tocs) {
            $reader = [IO.StreamReader]::new($toc.Open())
            try { $text = $reader.ReadToEnd() } finally { $reader.Dispose() }
            $tocVersion = [regex]::Match($text, '(?m)^## Version:\s*([^\r\n]+)').Groups[1].Value.Trim()
            if ($tocVersion -cne $version) { throw "TOC version $tocVersion does not match $Tag." }
            $interface = [regex]::Match($text, '(?m)^## Interface:\s*(16\d{3})\s*$').Groups[1].Value
            if (-not $interface) { throw 'Expected a WoW Forever interface number in every TOC.' }
            $interfaces += [int]$interface
        }
        $interfaces = @($interfaces | Select-Object -Unique)
        if ($interfaces.Count -ne 1) { throw 'Release contains conflicting interface versions.' }
        $interface = $interfaces[0]
        $gameVersion = '{0}.{1}.{2}' -f [math]::Floor($interface / 10000), [math]::Floor(($interface % 10000) / 100), ($interface % 100)
    } finally { $zip.Dispose() }

    $metadata = @{
        changelog = $release.body
        changelogType = 'markdown'
        displayName = $assetName
        releaseType = 'release'
        relations = @{ projects = @(@{ slug = $config.requiredDependency; type = 'requiredDependency' }) }
    }
    if ($DryRun) {
        Write-Output "Validated $assetName for CurseForge project $($config.projectId), WoW Forever $gameVersion. No upload performed."
        return
    }
    if ([string]::IsNullOrWhiteSpace($env:CF_API_TOKEN)) { throw 'Set the CF_API_TOKEN GitHub Actions secret before publishing.' }
    $headers = @{ 'X-Api-Token' = $env:CF_API_TOKEN }
    # Current WoW endpoint and Forever type are used by BigWigsMods/packager.
    $versions = Invoke-RestMethod -Uri 'https://wow.curseforge.com/api/game/wow/versions' -Headers $headers -TimeoutSec 60
    $matches = @($versions | Where-Object { $_.name -eq $gameVersion -and $_.gameVersionTypeID -eq 88568 })
    if ($matches.Count -ne 1) { throw "Could not resolve exactly one CurseForge WoW Forever $gameVersion ID." }
    $metadata.gameVersions = @([int]$matches[0].id)
    # Do not retry this POST automatically: an ambiguous timeout may already have created a file.
    $result = Invoke-RestMethod -Method Post -Uri "https://wow.curseforge.com/api/projects/$($config.projectId)/upload-file" -Headers $headers -Form @{
        metadata = ($metadata | ConvertTo-Json -Depth 6 -Compress)
        file = Get-Item -LiteralPath $zipPath
    } -TimeoutSec 300
    if (-not $result.id) { throw 'CurseForge did not return an uploaded file ID. Check its Files page before retrying.' }
    $message = "Uploaded $assetName to CurseForge project $($config.projectId), file $($result.id). CurseForge approval may still be pending."
    Write-Output $message
    if ($env:GITHUB_STEP_SUMMARY) { Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Value $message }
} finally {
    # This script-created temporary directory contains only the downloaded release ZIP.
    $resolvedTemp = [IO.Path]::GetFullPath($tempPath)
    $expectedParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar)
    if ([IO.Path]::GetDirectoryName($resolvedTemp) -eq $expectedParent -and [IO.Path]::GetFileName($resolvedTemp) -like 'curseforge-*') {
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
}
