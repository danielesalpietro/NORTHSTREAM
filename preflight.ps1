# NORTHSTREAM preflight: fails fast, with an actionable message, on a host
# that would otherwise let a container die in a bootstrap loop ten minutes
# in (P-6) instead of telling you why before you start (issue #19).
#
# This is an explicit, separate step - NOT invoked automatically by
# start-addon.ps1. See CHANGELOG.md / the Fase 1 logbook for why.
#
# Usage: .\preflight.ps1 [-Tier minimal|recommended|optimal] [-Gpu]
#                         [-RequireVramMib N] [-RequireRamMib N] [-AllowContention]
#
# -RequireVramMib N   declare how much free VRAM this run needs (issue #44);
#                     only checked with -Gpu. Default 0 - no requirement
#                     declared, VRAM is reported, not gated.
# -RequireRamMib N    declare how much RAM must actually be free (not just
#                     installed) for this run to start. Default 0 - same.
# -AllowContention    start anyway on a host that looks shared - a deliberate
#                     override, logged as a warning every time it is used.
#
# Note on parity with preflight.sh: the bash version attributes GPU compute
# processes to this project's own containers (cgroup match against 'docker
# ps'), so it can tell "shared" from "exclusive" even while our own stack is
# using the GPU. That attribution has no clean equivalent here - Docker
# Desktop runs containers inside its own WSL2 VM, invisible to a host-side
# PowerShell process list - so this script only reports total used/free VRAM
# and the count of GPU compute processes, without attempting ownership.
# preflight.ps1 has never been run against a real host (CLAUDE.md section 2:
# "mai collaudato su Windows/ENV-L"); this is best-effort parity, not a claim
# it has been verified against a real shared GPU on Windows.
param(
    [ValidateSet("minimal", "recommended", "optimal")]
    [string]$Tier = "minimal",
    [switch]$Gpu,
    [int]$RequireVramMib = 0,
    [int]$RequireRamMib = 0,
    [switch]$AllowContention
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
function Write-Info([string]$msg) { Write-Host "INFO  $msg" }

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

# RAM actually free right now (issue #44) - a different fact from total RAM
# above: a host with plenty of installed RAM can still have most of it
# claimed by another workload. Only gated when the caller declares a need
# (-RequireRamMib); otherwise this is descriptive, not a fabricated gate.
$freeRamMib = [math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1KB)
if ($RequireRamMib -gt 0) {
    if ($freeRamMib -ge $RequireRamMib) {
        Write-Ok "RAM free: $freeRamMib MiB (>= $RequireRamMib MiB declared with -RequireRamMib)"
    } elseif ($AllowContention) {
        Write-Warning "RAM free: $freeRamMib MiB is below the $RequireRamMib MiB this run declared it needs - starting anyway (-AllowContention)."
    } else {
        Write-Fail "RAM free: only $freeRamMib MiB available; this run declared it needs $RequireRamMib MiB free (-RequireRamMib). The host looks shared with another workload. Free RAM first, lower -RequireRamMib if the number was a guess, or pass -AllowContention to start anyway."
    }
} else {
    Write-Info "RAM free: $freeRamMib MiB (no -RequireRamMib declared - descriptive only)"
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

# Root-owned/unwritable directories in the repo tree (P-12, P-13). Same
# mechanism as P-11 seen from a third side: Docker (via Docker Desktop's
# Linux VM) can auto-create a bind-mount target that does not exist in the
# repository (trino/catalog) with ownership the checkout's own user cannot
# touch. On a workspace wiped every run this only breaks the *next* run's
# checkout (P-12); on a checkout someone keeps and updates, it breaks
# 'git pull'/'git checkout' outright, leaving the tree half-updated (P-13).
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$badDirs = @(Get-ChildItem -Path $repoRoot -Recurse -Directory -ErrorAction SilentlyContinue | Where-Object {
    $testFile = Join-Path $_.FullName ".preflight-write-test"
    try {
        [System.IO.File]::WriteAllText($testFile, "")
        Remove-Item -Path $testFile -ErrorAction SilentlyContinue
        $false
    } catch {
        $true
    }
})
if ($badDirs.Count -eq 0) {
    Write-Ok "no root-owned or otherwise unwritable directories in the repository tree"
} else {
    $badList = ($badDirs | ForEach-Object { $_.FullName }) -join ", "
    Write-Fail "not writable by the current user: $badList. Docker most likely created this via its own Linux VM - the same mechanism as P-11/P-12: a container auto-created a bind-mount target that did not exist. Left in place, this breaks 'git pull'/'git checkout' and leaves the working tree half-updated (P-13). This is Docker-managed state, not something to preserve: remove each path above, then re-run this preflight."
}

if ($Gpu) {
    $nvidiaSmi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
    if ($nvidiaSmi) {
        $gpuName = & nvidia-smi -L | Select-Object -First 1
        Write-Ok "GPU: $gpuName"

        # GPU exclusivity (issue #44) - no container attribution on Windows
        # (see the note above the param block): "shared" here means "a
        # foreign compute process is running", not "ours is legitimately
        # using the GPU too". Read before the stack starts, that distinction
        # does not matter - nothing of ours should be on the GPU yet.
        try {
            $memLine = & nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits | Select-Object -First 1
            $memParts = $memLine -split ",\s*"
            $usedMib = [int]$memParts[0]
            $totalMib = [int]$memParts[1]
            $freeMib = $totalMib - $usedMib
            $procCount = 0
            $procOut = & nvidia-smi --query-compute-apps=pid,used_memory --format=csv,noheader,nounits 2>$null
            if ($LASTEXITCODE -eq 0 -and $procOut) {
                $procCount = @($procOut | Where-Object { $_.Trim() -ne "" }).Count
            }
            if ($RequireVramMib -gt 0 -and $freeMib -lt $RequireVramMib) {
                if ($AllowContention) {
                    Write-Warning "GPU exclusivity (#44): $usedMib/$totalMib MiB used ($procCount compute process(es) seen, unattributed on Windows), $freeMib MiB free; this run declared it needs $RequireVramMib MiB. Starting anyway (-AllowContention)."
                } else {
                    Write-Fail "GPU exclusivity (#44): only $freeMib MiB free ($usedMib/$totalMib MiB used, $procCount compute process(es) seen) - this run declared it needs $RequireVramMib MiB (-RequireVramMib) and will not fit. Wait for the GPU to free up, lower the model/tier, or pass -AllowContention to force it."
                }
            } elseif ($procCount -gt 0 -or $usedMib -gt 64) {
                Write-Warning "GPU exclusivity (#44): $usedMib/$totalMib MiB used, $procCount compute process(es) seen before this project's own stack has started - looks shared (no -RequireVramMib declared, or $freeMib MiB free still covers it)."
            } else {
                Write-Ok "GPU exclusivity (#44): $usedMib/$totalMib MiB used, no compute process seen - looks exclusive"
            }
        } catch {
            Write-Warning "GPU exclusivity (#44): could not read nvidia-smi memory/process output ($_) - treating as unknown, not as contention."
        }
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
