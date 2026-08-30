# Starts NORTHSTREAM base stack + Stream Context Agent addon.
# Usage: .\start-addon.ps1                        (everything, CPU only - today's default)
#        .\start-addon.ps1 -Gpu                   (everything, GPU passthrough for Ollama)
#        .\start-addon.ps1 -Profile core          (lean pipeline only: P-5, issue #21)
#        .\start-addon.ps1 -Profile core,lakehouse -Gpu
#
# Compose profiles (core/lakehouse/governance) were introduced in v0.0.3.
# Default stays "start everything" by passing all three profiles unless
# -Profile narrows it. core services have no profile tag of their own, so
# they start regardless of which profiles are requested.
param(
    [switch]$Gpu,
    [string]$Profile = "core,lakehouse,governance"
)
$ErrorActionPreference = "Stop"

$composeArgs = @(
    "-f", "docker-compose-northstream-ai.yml",
    "-f", "docker-compose.addon.yml"
)

if ($Gpu) {
    $composeArgs += @("-f", "docker-compose.gpu.yml")
}

foreach ($p in $Profile -split ",") {
    $composeArgs += @("--profile", $p)
}

docker compose @composeArgs up -d --build
