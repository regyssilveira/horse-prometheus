# Script de Teste de Integração E2E para o Horse Prometheus
$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path ".."
$SamplesDir = Join-Path $ProjectRoot "samples\Delphi"
$BinPath = Join-Path $SamplesDir "Sample.exe"
$RsvarsPath = "C:\Program Files (x86)\Embarcadero\Studio\17.0\bin\rsvars.bat"
$BdsPath = "C:\Program Files (x86)\Embarcadero\Studio\17.0"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Iniciando Teste de Integração (E2E)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. Compilar o Sample se necessário
Write-Host "Compilando o servidor de teste (Sample.dpr)..." -ForegroundColor Gray
$CmdLine = "call `"$RsvarsPath`" && dcc32 -NS`"System;Xml;Data;Web;Soap;Winapi;System.Win`" -U`"$BdsPath\lib\Win32\Release`" -U`"$ProjectRoot`" -U`"$ProjectRoot\modules\horse\src`" -E`"$SamplesDir`" `"$SamplesDir\Sample.dpr`""
cmd.exe /c $CmdLine

if ($LASTEXITCODE -ne 0) {
    Write-Error "Falha na compilação do exemplo."
}

Write-Host "Servidor de teste compilado com sucesso!" -ForegroundColor Green

# 2. Iniciar o servidor em segundo plano
Write-Host "Iniciando servidor de teste na porta 9000 em segundo plano..." -ForegroundColor Gray
$Process = Start-Process -FilePath $BinPath -NoNewWindow -PassThru

# Garantir que o processo seja encerrado ao final
$ProcessId = $Process.Id
Write-Host "Servidor iniciado com PID $ProcessId." -ForegroundColor Gray

try {
    # Aguardar o startup da API
    Start-Sleep -Seconds 2

    # 3. Executar chamadas de negócio simulando tráfego
    Write-Host "Simulando trafego de requisições na API..." -ForegroundColor Gray
    
    # 3x GET /ping (Status 200)
    for ($i = 1; $i -le 3; $i++) {
        curl.exe -s "http://localhost:9000/ping" | Out-Null
    }
    # 2x GET /users (Status 200)
    for ($i = 1; $i -le 2; $i++) {
        curl.exe -s "http://localhost:9000/users" | Out-Null
    }
    # 1x POST /users (Status 201)
    curl.exe -s -X POST "http://localhost:9000/users" | Out-Null

    # 4. Chamar o endpoint de métricas
    Write-Host "Efetuando scraping de http://localhost:9000/metrics..." -ForegroundColor Gray
    $MetricsText = curl.exe -s "http://localhost:9000/metrics"

    Write-Host "`n--- Metricas Retornadas pelo Servidor ---" -ForegroundColor Yellow
    Write-Host $MetricsText -ForegroundColor DarkGray
    Write-Host "-----------------------------------------`n" -ForegroundColor Yellow

    # 5. Fazer asserções nas métricas coletadas
    $Pass = $true

    if ($MetricsText -match 'http_requests_total\{method="GET",route="/ping",status="200"\} 3') {
        Write-Host "[OK] GET /ping (Status 200) computado 3 vezes." -ForegroundColor Green
    } else {
        Write-Host "[FAIL] Metrica GET /ping com valor esperado de 3 não encontrada." -ForegroundColor Red
        $Pass = $false
    }

    if ($MetricsText -match 'http_requests_total\{method="GET",route="/users",status="200"\} 2') {
        Write-Host "[OK] GET /users (Status 200) computado 2 vezes." -ForegroundColor Green
    } else {
        Write-Host "[FAIL] Metrica GET /users com valor esperado de 2 não encontrada." -ForegroundColor Red
        $Pass = $false
    }

    if ($MetricsText -match 'http_requests_total\{method="POST",route="/users",status="201"\} 1') {
        Write-Host "[OK] POST /users (Status 201) computado 1 vez." -ForegroundColor Green
    } else {
        Write-Host "[FAIL] Metrica POST /users com valor esperado de 1 não encontrada." -ForegroundColor Red
        $Pass = $false
    }

    if ($MetricsText -match 'http_request_duration_seconds_sum\{method="GET",route="/ping"\}') {
        Write-Host "[OK] Metrica de latencias (duration sum/count) gerada com sucesso." -ForegroundColor Green
    } else {
        Write-Host "[FAIL] Medicoes de duracao das requisicoes nao encontradas." -ForegroundColor Red
        $Pass = $false
    }

    if ($Pass) {
        Write-Host "`n==========================================" -ForegroundColor Green
        Write-Host "RESULTADO: TODOS OS TESTES E2E PASSARAM!" -ForegroundColor Green
        Write-Host "==========================================" -ForegroundColor Green
    } else {
        Write-Error "Alguns testes de integração falharam."
    }

} finally {
    # 6. Garantir parada do servidor
    Write-Host "Finalizando processo do servidor com PID $ProcessId..." -ForegroundColor Gray
    Stop-Process -Id $ProcessId -Force
}
