# Starts NORTHSTREAM base stack + Stream Context Agent addon.
# Usage: .\start-addon.ps1          (CPU only)
#        .\start-addon.ps1 -Gpu     (adds NVIDIA GPU passthrough for Ollama)
param(
    [switch]$Gpu
)
$ErrorActionPreference = "Stop"

$composeArgs = @(
    "-f", "docker-compose-northstream-ai.yml",
    "-f", "docker-compose.addon.yml"
)

if ($Gpu) {
    $composeArgs += @("-f", "docker-compose.gpu.yml")
}

docker compose @composeArgs up -d --build
