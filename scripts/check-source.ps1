#Requires -Version 7.0

[CmdletBinding()]
param(
    [string]$InstalledDirectory,
    [string]$CompareScript = (Join-Path ([Environment]::GetFolderPath('UserProfile')) '.codex/skills/wow-addon-dev/scripts/Compare-AddonInstall.ps1')
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

function Show-Manifest([string]$Path) {
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) {
        Write-Output "  Missing TOC $(Split-Path -Leaf $Path)"
        return
    }

    $name = Split-Path -Leaf $Path
    $metadata = Get-Content -LiteralPath $Path | Select-String '^## (Version|Interface):'
    Write-Output "  $name"
    foreach ($line in $metadata) {
        Write-Output "    $($line.Line.Substring(3))"
    }
}

try {
    $worktree = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
    $addonName = 'ForeverProfessionPlanner'
    $sourceDirectory = Join-Path $worktree "addon/$addonName"
    $sourceToc = "$addonName.toc"
    $foreverToc = "${addonName}_Forever.toc"
    if (!$InstalledDirectory) {
        $programFiles = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
        if (!$programFiles) { $programFiles = $env:ProgramFiles }
        if (!$programFiles) { throw 'Specify the WoW Forever addon folder with -InstalledDirectory.' }
        $InstalledDirectory = Join-Path $programFiles "World of Warcraft/_forever_/Interface/AddOns/$addonName"
    }

    $branch = git -C $worktree rev-parse --abbrev-ref HEAD
    $revision = git -C $worktree rev-parse --short HEAD
    $changes = @(git --no-optional-locks -C $worktree status --short --untracked-files=normal)
    $status = if ($changes.Count) { 'has uncommitted changes' } else { 'clean' }
    Write-Output "Source worktree $worktree"
    Write-Output "  $branch @ $revision ($status)"
    Show-Manifest (Join-Path $sourceDirectory $sourceToc)

    Write-Output "Installed addon $InstalledDirectory"
    $installedToc = $foreverToc
    if (!(Test-Path -LiteralPath (Join-Path $InstalledDirectory $foreverToc) -PathType Leaf) -and
        (Test-Path -LiteralPath (Join-Path $InstalledDirectory $sourceToc) -PathType Leaf)) {
        $installedToc = $sourceToc
    }
    Show-Manifest (Join-Path $InstalledDirectory $installedToc)

    if (!(Test-Path -LiteralPath $InstalledDirectory -PathType Container)) {
        throw 'Installed addon folder is missing. Use -InstalledDirectory for a different install.'
    }
    if (!(Test-Path -LiteralPath $CompareScript -PathType Leaf)) {
        throw "WoW addon dev comparator missing at '$CompareScript'. Use -CompareScript to point to a copy."
    }

    $LASTEXITCODE = 0
    & $CompareScript -SourceDirectory $sourceDirectory `
        -InstalledDirectory $InstalledDirectory -SourceToc $sourceToc -InstalledToc $installedToc
    exit $LASTEXITCODE
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 2
}
