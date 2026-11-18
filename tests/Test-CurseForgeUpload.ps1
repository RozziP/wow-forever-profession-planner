#Requires -Version 7.0
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$config = Get-Content (Join-Path $root 'scripts/curseforge.json') -Raw | ConvertFrom-Json
$publisher = Join-Path $root 'scripts/publish-curseforge.ps1'
$oldToken = $env:CF_API_TOKEN
$oldSummary = $env:GITHUB_STEP_SUMMARY
$env:CF_API_TOKEN = 'test-token-not-a-credential'
$env:GITHUB_STEP_SUMMARY = ''
$global:curseForgeUploadTestState = @{
    version = '1.2.3'; interface = '16001'; prerelease = $false; assetMissing = $false
    versionMissing = $false; posts = 0; gets = 0; uploadFails = $false; metadata = $null
}

# Both external boundaries are mocked; these checks cannot publish anything.
function gh {
    $global:LASTEXITCODE = 0
    $asset = "$($config.assetPrefix)-1.2.3-forever.zip"
    if ($args[0] -ne 'release') { throw 'Unexpected gh command.' }
    if ($args[1] -eq 'view') {
        return (@{
            tagName = 'v1.2.3'; isDraft = $false; isPrerelease = $global:curseForgeUploadTestState.prerelease
            body = "Changes with quotes, `$variables, and`nmultiple lines."
            assets = $(if ($global:curseForgeUploadTestState.assetMissing) { @() } else { @(@{ name = $asset }) })
        } | ConvertTo-Json -Depth 6)
    }
    if ($args[1] -ne 'download') { throw 'Unexpected gh command.' }
    $dest = $args[[array]::IndexOf($args, '--dir') + 1]
    $zip = [IO.Compression.ZipFile]::Open((Join-Path $dest $asset), 'Create')
    try {
        $entry = $zip.CreateEntry("$($config.addonFolder)/$($config.addonFolder)_Forever.toc")
        $writer = [IO.StreamWriter]::new($entry.Open())
        try { $writer.Write("## Interface: $($global:curseForgeUploadTestState.interface)`r`n## Version: $($global:curseForgeUploadTestState.version)`r`n") }
        finally { $writer.Dispose() }
    } finally { $zip.Dispose() }
}
function Invoke-RestMethod {
    param($Uri, $Headers, $TimeoutSec, $Method = 'Get', $Form)
    if ($Headers['X-Api-Token'] -ne 'test-token-not-a-credential') { throw 'Incorrect authentication header.' }
    if ($Method -eq 'Get') {
        $global:curseForgeUploadTestState.gets++
        if ($Uri -ne 'https://wow.curseforge.com/api/game/wow/versions') { throw 'Wrong version endpoint.' }
        if ($global:curseForgeUploadTestState.versionMissing) { return @() }
        return @(@{ name = '1.60.1'; gameVersionTypeID = 517; id = 999 }, @{ name = '1.60.1'; gameVersionTypeID = 88568; id = 123 })
    }
    $global:curseForgeUploadTestState.posts++
    if ($Uri -ne "https://wow.curseforge.com/api/projects/$($config.projectId)/upload-file") { throw 'Wrong project endpoint.' }
    if ($global:curseForgeUploadTestState.uploadFails) { throw 'Simulated timeout.' }
    if ($Form.file -isnot [IO.FileInfo] -or -not $Form.file.Exists) { throw 'Missing multipart ZIP.' }
    $global:curseForgeUploadTestState.metadata = $Form.metadata | ConvertFrom-Json
    return @{ id = 456 }
}
function Expect-Failure([scriptblock]$Action, [string]$Pattern) {
    try { & $Action | Out-Null } catch {
        if ($_.Exception.Message -notlike $Pattern) { throw }
        return
    }
    throw "Expected failure matching $Pattern."
}
try {
    & $publisher -Tag v1.2.3 -DryRun
    if ($global:curseForgeUploadTestState.posts -or $global:curseForgeUploadTestState.gets) { throw 'Dry run called CurseForge.' }
    & $publisher -Tag v1.2.3
    $m = $global:curseForgeUploadTestState.metadata
    if ($global:curseForgeUploadTestState.posts -ne 1 -or $m.gameVersions.Count -ne 1 -or $m.gameVersions[0] -ne 123 -or
        $m.relations.projects[0].slug -ne $config.requiredDependency -or $m.changelog -notmatch 'multiple lines') {
        throw 'Incorrect upload metadata.'
    }
    $global:curseForgeUploadTestState.version = '0.0.0'
    Expect-Failure { & $publisher -Tag v1.2.3 } '*does not match*'
    $global:curseForgeUploadTestState.version = '1.2.3'
    $global:curseForgeUploadTestState.interface = '120107'
    Expect-Failure { & $publisher -Tag v1.2.3 } '*WoW Forever interface*'
    $global:curseForgeUploadTestState.interface = '16001'
    $global:curseForgeUploadTestState.prerelease = $true
    Expect-Failure { & $publisher -Tag v1.2.3 } '*published stable release*'
    $global:curseForgeUploadTestState.prerelease = $false
    $global:curseForgeUploadTestState.assetMissing = $true
    Expect-Failure { & $publisher -Tag v1.2.3 } '*exactly one release asset*'
    $global:curseForgeUploadTestState.assetMissing = $false
    $global:curseForgeUploadTestState.versionMissing = $true
    Expect-Failure { & $publisher -Tag v1.2.3 } '*resolve exactly one*'
    $global:curseForgeUploadTestState.versionMissing = $false
    $env:CF_API_TOKEN = ''
    Expect-Failure { & $publisher -Tag v1.2.3 } '*Set the CF_API_TOKEN*'
    $env:CF_API_TOKEN = 'test-token-not-a-credential'
    if ($global:curseForgeUploadTestState.posts -ne 1) { throw 'Invalid release reached the upload endpoint.' }
    $global:curseForgeUploadTestState.uploadFails = $true
    Expect-Failure { & $publisher -Tag v1.2.3 } '*Simulated timeout*'
    if ($global:curseForgeUploadTestState.posts -ne 2) { throw 'Upload was retried after an ambiguous failure.' }
    Write-Output 'PASS: upload metadata, dry run, invalid releases, missing token/version, and no POST retry.'
} finally {
    $env:CF_API_TOKEN = $oldToken
    $env:GITHUB_STEP_SUMMARY = $oldSummary
    Remove-Variable -Name curseForgeUploadTestState -Scope Global
}
