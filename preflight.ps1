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

# kafka_data volume vs apache/kafka's user (P-11). bitnamilegacy/kafka:3.7.1
# ran as uid=1001 gid=0(root); apache/kafka:4.3.1 (#17) runs as
# uid=1000(appuser) gid=1000. A kafka_data volume already populated by the
# old image is left 0:0 mode 775 - writable by the group root the old
# broker belonged to, not by the new one's gid 1000. The broker's own error
# in that state (AccessDeniedException on a checkpoint file) never mentions
# permissions or the image change, and CI cannot catch this: every
# ci-smoke/ci-nightly run starts from a volume that does not exist yet.
$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
if ($dockerCmd) {
    docker info *> $null
    if ($LASTEXITCODE -eq 0) {
        $kafkaVol = (docker volume ls `
            --filter "label=com.docker.compose.project=wap-northstream-lab" `
            --filter "label=com.docker.compose.volume=kafka_data" `
            --format "{{.Name}}") | Select-Object -First 1
        if (-not $kafkaVol) {
            Write-Ok "no pre-existing kafka_data volume - nothing to migrate (P-11 does not apply to a fresh install)"
        } else {
            $probeOut = docker run --rm --user 1000:1000 -v "${kafkaVol}:/check" busybox `
                sh -c 'touch /check/.preflight-write-test && rm -f /check/.preflight-write-test' 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Ok "kafka_data volume ($kafkaVol) is writable by uid 1000 (apache/kafka's user)"
            } elseif ($probeOut -match "(?i)permission denied") {
                Write-Fail "kafka_data volume ($kafkaVol) is NOT writable by uid 1000 (apache/kafka's user, since #17/P-3). This volume was populated by the old bitnamilegacy/kafka image (uid 1001, gid 0) and the new one (uid 1000, gid 1000) cannot write to it - the broker will crash-loop with 'AccessDeniedException' on a checkpoint file, with no mention of permissions in the error. This data is a disposable local cache, not something to preserve: remove it and let the new image recreate it - 'docker volume rm $kafkaVol' (stack stopped), or 'docker compose down -v' for a full reset."
            } else {
                Write-Warning "could not verify kafka_data volume ($kafkaVol) ownership (P-11): $probeOut"
            }
        }
    } else {
        Write-Warning "docker CLI present but daemon not reachable - cannot check the kafka_data volume for P-11"
    }
} else {
    Write-Warning "docker not available - cannot check the kafka_data volume for P-11"
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
