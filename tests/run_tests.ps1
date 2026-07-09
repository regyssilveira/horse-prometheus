# Script para compilar e rodar os testes em Delphi e Lazarus (FPC)
$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path ".."
$TestsDir = Join-Path $ProjectRoot "tests"
$BinDir = Join-Path $TestsDir "bin"
$DelphiBin = Join-Path $BinDir "delphi"
$LazarusBin = Join-Path $BinDir "lazarus"

# Garantir que os diretórios de saída existam
New-Item -ItemType Directory -Force -Path $DelphiBin | Out-Null
New-Item -ItemType Directory -Force -Path $LazarusBin | Out-Null

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Iniciando compilação e teste: Delphi (DCC32)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# Caminhos do Delphi
$RsvarsPath = "C:\Program Files (x86)\Embarcadero\Studio\17.0\bin\rsvars.bat"
$BdsPath = "C:\Program Files (x86)\Embarcadero\Studio\17.0"

if (Test-Path $RsvarsPath) {
    # Compilar Delphi
    $CmdLine = "call `"$RsvarsPath`" && dcc32 -NS`"System;Xml;Data;Web;Soap;Winapi;System.Win`" -U`"$BdsPath\lib\Win32\Release`" -U`"$ProjectRoot`" -U`"$ProjectRoot\modules\horse\src`" -E`"$DelphiBin`" -N`"$DelphiBin`" `"$TestsDir\Horse.Prometheus.Tests.dpr`""

    Write-Host "Compilando com DCC32..." -ForegroundColor Gray
    cmd.exe /c $CmdLine

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Compilação concluída com sucesso! Executando testes..." -ForegroundColor Green
        $DelphiExe = Join-Path $DelphiBin "Horse.Prometheus.Tests.exe"
        & $DelphiExe
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Falha nos testes compilados com Delphi."
        }
    } else {
        Write-Error "Falha na compilação do Delphi."
    }
} else {
    Write-Host "Aviso: rsvars.bat não encontrado em $RsvarsPath. Pulando testes do Delphi." -ForegroundColor Yellow
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Iniciando compilação e teste: Lazarus (FPC)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$FpcPath = "C:\lazarus\fpc\3.2.2\bin\i386-win32\fpc.exe"

if (Test-Path $FpcPath) {
    Write-Host "Compilando com FPC..." -ForegroundColor Gray
    # Compilar FPC
    & $FpcPath -Mdelphi -FE"$LazarusBin" -FU"$LazarusBin" -Fu"$ProjectRoot" -Fu"$ProjectRoot\modules\horse\src" "$TestsDir\Horse.Prometheus.Tests.dpr"

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Compilação concluída com sucesso! Executando testes..." -ForegroundColor Green
        $FpcExe = Join-Path $LazarusBin "Horse.Prometheus.Tests.exe"
        & $FpcExe
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Falha nos testes compilados com FPC."
        }
    } else {
        Write-Error "Falha na compilação com FPC."
    }
} else {
    Write-Host "Aviso: FPC não encontrado em $FpcPath. Pulando testes do Lazarus/FPC." -ForegroundColor Yellow
}

Write-Host "==========================================" -ForegroundColor Green
Write-Host "Processo concluído." -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
