# NORTHSTREAM preflight: fails fast, with an actionable message, on a host
# that would otherwise let a container die in a bootstrap loop ten minutes
# in (P-6) instead of telling you why before you start (issue #19).
#
# This is an explicit, separate step - NOT invoked automatically by
# start-addon.ps1. See CHANGELOG.md / the Fase 1 logbook for why.
#
# Usage: .\preflight.ps1 [-Tier minimal|recommended|optimal] [-Gpu]
param(
    [ValidateSet("minimal", "recommended", "optimal")]
    [string]$Tier = "minimal",
    [switch]$Gpu
)
$ErrorActionPreference = "Stop"

# Floors mirror the hardware table in README.md ("Hardware & Model Tiers"):
# keep the two in sync if the table ever changes.
$tiers = @{
    minimal     = @{ RamGb = 16; DiskGb = 30 }
    recommended = @{ RamGb = 32; DiskGb = 50 }
    optimal     = @{ RamGb = 32; DiskGb = 80 }
}
$want = $tiers[$Tier]

$script:fail = $false
function Write-Ok([string]$msg) { Write-Host "OK    $msg" }
function Write-Fail([string]$msg) { Write-Host "FAIL  $msg" -ForegroundColor Red; $script:fail = $true }

# vm.max_map_count (P-6) is a Linux kernel setting checked by Elasticsearch /
# OpenMetadata at bootstrap. On native Windows, Docker Desktop runs
# containers inside its own WSL2/Hyper-V VM and presets it there; there is
# no host-side equivalent to check from PowerShell, so this is informational.
Write-Warning "vm.max_map_count (P-6, Elasticsearch bootstrap) is preset by Docker Desktop's own VM on Windows - not checked here."

$totalRamGb = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
if ($totalRamGb -ge $want.RamGb) {
    Write-Ok "RAM: $totalRamGb GiB (>= $($want.RamGb) GiB for tier '$Tier')"
} else {
    Write-Fail "RAM: $totalRamGb GiB is below the $($want.RamGb) GiB the '$Tier' tier needs (README hardware table). The stack may still start but is likely to OOM under load."
}

$drive = (Get-Location).Drive
$freeGb = [math]::Round($drive.Free / 1GB)
if ($freeGb -ge $want.DiskGb) {
    Write-Ok "free disk on $($drive.Name): $freeGb GiB (>= $($want.DiskGb) GiB for tier '$Tier')"
} else {
    Write-Fail "free disk on $($drive.Name): $freeGb GiB is below the $($want.DiskGb) GiB the '$Tier' tier needs for images and volumes."
}

if ($Gpu) {
    $nvidiaSmi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
    if ($nvidiaSmi) {
        $gpuName = & nvidia-smi -L | Select-Object -First 1
        Write-Ok "GPU: $gpuName"
    } else {
        Write-Fail "GPU: -Gpu was requested but 'nvidia-smi' was not found. Install the current NVIDIA driver for WSL2 (not a separate in-distro driver) before passing -Gpu to start-addon.ps1."
    }
}

Write-Host ""
if ($script:fail) {
    Write-Host "preflight FAILED - fix the FAIL line(s) above before starting the stack." -ForegroundColor Red
    exit 1
}
Write-Host "preflight OK - this host meets the requirements for tier '$Tier'."
