# Script para gerar tráfego de teste de forma contínua na API do Horse Prometheus
$ErrorActionPreference = "Continue"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Gerador de Tráfego Contínuo - Horse Prometheus" -ForegroundColor Cyan
Write-Host "Alvo: http://localhost:9000" -ForegroundColor Cyan
Write-Host "Pressione CTRL+C para parar a simulação" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$Endpoints = @(
    @{ Path = "ping"; Method = "GET" },
    @{ Path = "users"; Method = "GET" },
    @{ Path = "users"; Method = "POST" },
    @{ Path = "notfound"; Method = "GET" } # Rota inexistente para gerar status 404
)

$TotalRequests = 0

while ($true) {
    # Seleciona um endpoint aleatório
    $Endpoint = $Endpoints | Get-Random
    $Uri = "http://localhost:9000/$($Endpoint.Path)"
    $Method = $Endpoint.Method

    try {
        # Dispara via curl.exe (mais leve e rápido que Invoke-WebRequest)
        if ($Method -eq "POST") {
            $null = curl.exe -s -X POST $Uri
        } else {
            $null = curl.exe -s $Uri
        }
        
        $TotalRequests++
        if ($TotalRequests % 20 -eq 0) {
            Write-Host "Total de requisições enviadas: $TotalRequests" -ForegroundColor Green
        }
    } catch {
        Write-Host "Erro ao conectar na API. Verifique se o Sample.exe está rodando na porta 9000." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
    }

    # Delay dinâmico aleatório (5ms a 100ms) para simular acessos paralelos/reais
    $Delay = Get-Random -Minimum 5 -Maximum 100
    Start-Sleep -Milliseconds $Delay
}
