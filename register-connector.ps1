# Registers the Debezium Postgres CDC connector with Kafka Connect.
$ErrorActionPreference = "Stop"

Invoke-RestMethod -Uri "http://localhost:8083/connectors" `
  -Method Post `
  -ContentType "application/json" `
  -InFile "connectors\postgres-source-connector.json"

Write-Host ""
Write-Host "Connector status:"
Invoke-RestMethod -Uri "http://localhost:8083/connectors/northstream-postgres-connector/status"
