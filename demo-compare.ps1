# Asks the stream-agent the same question with and without live stream context.
param(
    [string]$Question = "Are there any recent sensor anomalies at Plant-B?"
)

$ErrorActionPreference = "Stop"

$body = @{ question = $Question } | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:8500/compare" `
  -Method Post `
  -ContentType "application/json" `
  -Body $body
