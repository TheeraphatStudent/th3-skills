<#
.SYNOPSIS
  Reclaim disk space from a Podman machine on Windows (WSL2 backend).

.DESCRIPTION
  1. Prune unused images (and optionally stopped containers / unused volumes).
  2. fstrim inside the machine so freed ext4 blocks are unmapped.
  3. Stop the machine, `wsl --shutdown`, compact ext4.vhdx with diskpart.
  4. Start the machine again and print before/after sizes.

  Pruning frees space inside the VM. Only step 3 gives space back to Windows.
  Compaction needs an elevated (Administrator) PowerShell.

.EXAMPLE
  .\reclaim.ps1 -DryRun
  .\reclaim.ps1                      # prune unused images + compact
  .\reclaim.ps1 -Containers -Volumes # also drop stopped containers and unused volumes
  .\reclaim.ps1 -SkipPrune           # compact only, delete nothing
#>
[CmdletBinding()]
param(
  [string]$Machine = 'podman-machine-default',
  [switch]$Containers,
  [switch]$Volumes,
  [switch]$SkipPrune,
  [switch]$SkipCompact,
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$env:WSL_UTF8 = '1'

function Step([string]$Label, [scriptblock]$Action) {
  Write-Host "==> $Label" -ForegroundColor Cyan
  if ($DryRun) { return }
  $global:LASTEXITCODE = 0
  & $Action
  if ($LASTEXITCODE) { throw "$Label failed (exit $LASTEXITCODE)" }
}

function Get-VhdxPath {
  $dist = Get-ChildItem 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss' |
    ForEach-Object { Get-ItemProperty $_.PSPath } |
    Where-Object DistributionName -eq $Machine
  if (-not $dist) { throw "WSL distro '$Machine' not found. Is this a WSL-backed Podman machine?" }
  Join-Path ($dist.BasePath -replace '^\\\\\?\\', '') 'ext4.vhdx'
}

function Get-SizeGB([string]$Path) { [math]::Round((Get-Item $Path).Length / 1GB, 2) }

function Wait-Unlocked([string]$Path) {
  foreach ($i in 1..30) {
    try { [IO.File]::Open($Path, 'Open', 'ReadWrite', 'None').Dispose(); return }
    catch { Start-Sleep -Seconds 1 }
  }
  throw "$Path is still locked after wsl --shutdown. Close anything using WSL and retry."
}

$vhdx = Get-VhdxPath
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).
  IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $SkipCompact -and -not $DryRun -and -not $isAdmin) {
  throw 'Compaction needs an elevated PowerShell. Re-run as Administrator, or pass -SkipCompact.'
}

$before = Get-SizeGB $vhdx
Write-Host "Machine : $Machine"
Write-Host "VHDX    : $vhdx ($before GB on host)"
podman system df

if ((podman machine inspect --format '{{.State}}' $Machine) -ne 'running') {
  Step 'Start machine' { podman machine start $Machine }
}

if (-not $SkipPrune) {
  if ($Containers) { Step 'Prune stopped containers' { podman container prune -f } }
  Step 'Prune unused images' { podman image prune -a -f }
  if ($Volumes) { Step 'Prune unused volumes' { podman volume prune -f } }
}

if (-not $SkipCompact) {
  # fstrim first: diskpart can only reclaim blocks the guest has unmapped.
  Step 'fstrim inside machine' { wsl -d $Machine -u root -- fstrim -av }
  Step 'Stop machine' { podman machine stop $Machine }
  # ponytail: shuts down every WSL distro, not just this one; needed so the vhdx is released.
  Step 'wsl --shutdown (stops ALL WSL distros)' { wsl --shutdown }
  Step 'Compact vhdx with diskpart' {
    Wait-Unlocked $vhdx
    $script = Join-Path $env:TEMP 'podman-reclaim.diskpart'
    @"
select vdisk file="$vhdx"
attach vdisk readonly
compact vdisk
detach vdisk
"@ | Set-Content -Encoding ascii $script
    diskpart /s $script
    Remove-Item $script
  }
  Step 'Start machine' { podman machine start $Machine }
}

if ($DryRun) { Write-Host 'Dry run: nothing changed.' -ForegroundColor Yellow; return }

$after = Get-SizeGB $vhdx
podman system df
Write-Host ("VHDX on host: {0} GB -> {1} GB (freed {2} GB)" -f $before, $after, [math]::Round($before - $after, 2)) -ForegroundColor Green
