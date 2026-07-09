unit Horse.Prometheus.Tests.Cases;

{$IFDEF FPC}
  {$MODE DELPHI}{$H+}
{$ENDIF}

interface

procedure RunAllTests;

implementation

uses
  {$IFDEF FPC}
    SysUtils, Classes, Generics.Collections,
  {$ELSE}
    System.SysUtils, System.Classes, System.Generics.Collections,
  {$ENDIF}
  Horse.Prometheus;

var
  GTestsFailed: Integer = 0;
  GTestsPassed: Integer = 0;

procedure AssertEqual(const AExpected, AActual: string; const AMessage: string);
begin
  if AExpected <> AActual then
  begin
    Writeln('[FAIL] ', AMessage, ' - Expected: "', AExpected, '", Actual: "', AActual, '"');
    Inc(GTestsFailed);
  end
  else
  begin
    Writeln('[PASS] ', AMessage);
    Inc(GTestsPassed);
  end;
end;

procedure AssertTrue(const ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
  begin
    Writeln('[FAIL] ', AMessage, ' - Expected: True, Actual: False');
    Inc(GTestsFailed);
  end
  else
  begin
    Writeln('[PASS] ', AMessage);
    Inc(GTestsPassed);
  end;
end;

type
  THorsePrometheusExposed = class(THorsePrometheus)
  public
    class function GetRequestsTotal: TDictionary<string, Int64>;
    class function GetRequestDurationSum: TDictionary<string, Double>;
    class function GetRequestDurationCount: TDictionary<string, Int64>;
    class function GetActiveRequests: Integer;
    class procedure SetActiveRequests(const AValue: Integer);
    class function CallFormatMetrics: string;
    class procedure ClearMetrics;
  end;

class function THorsePrometheusExposed.GetRequestsTotal: TDictionary<string, Int64>;
begin
  Result := FRequestsTotal;
end;

class function THorsePrometheusExposed.GetRequestDurationSum: TDictionary<string, Double>;
begin
  Result := FRequestDurationSum;
end;

class function THorsePrometheusExposed.GetRequestDurationCount: TDictionary<string, Int64>;
begin
  Result := FRequestDurationCount;
end;

class function THorsePrometheusExposed.GetActiveRequests: Integer;
begin
  Result := FActiveRequests;
end;

class procedure THorsePrometheusExposed.SetActiveRequests(const AValue: Integer);
begin
  FActiveRequests := AValue;
end;

class function THorsePrometheusExposed.CallFormatMetrics: string;
begin
  Result := FormatMetrics;
end;

class procedure THorsePrometheusExposed.ClearMetrics;
begin
  FLock.Enter;
  try
    FRequestsTotal.Clear;
    FRequestDurationSum.Clear;
    FRequestDurationCount.Clear;
    FActiveRequests := 0;
  finally
    FLock.Leave;
  end;
end;

procedure TestMetricsPath;
begin
  Writeln('--- TestMetricsPath ---');
  
  // Caminho padrão
  AssertEqual('/metrics', THorsePrometheusExposed.GetMetricsPath, 'MetricsPath padrao');

  // Definindo com barras e espaços
  THorsePrometheusExposed.SetMetricsPath('custom');
  AssertEqual('/custom', THorsePrometheusExposed.GetMetricsPath, 'SetMetricsPath sem barra');

  THorsePrometheusExposed.SetMetricsPath('/custom2/');
  AssertEqual('/custom2', THorsePrometheusExposed.GetMetricsPath, 'SetMetricsPath com barras extras');

  // Resetar
  THorsePrometheusExposed.SetMetricsPath('metrics');
end;

procedure TestFormatMetricsEmpty;
var
  LMetrics: string;
begin
  Writeln('--- TestFormatMetricsEmpty ---');
  THorsePrometheusExposed.ClearMetrics;

  LMetrics := THorsePrometheusExposed.CallFormatMetrics;

  AssertTrue(LMetrics.Contains('http_active_requests 0'), 'Active requests deve ser 0');
  AssertTrue(LMetrics.Contains('# HELP http_requests_total'), 'Contem HELP requests total');
  AssertTrue(LMetrics.Contains('# TYPE http_requests_total counter'), 'Contem TYPE requests total');
end;

procedure TestFormatMetricsWithData;
var
  LMetrics: string;
begin
  Writeln('--- TestFormatMetricsWithData ---');
  THorsePrometheusExposed.ClearMetrics;

  // Mock de dados
  THorsePrometheusExposed.SetActiveRequests(3);
  THorsePrometheusExposed.GetRequestsTotal.Add('GET:/ping:200', 5);
  THorsePrometheusExposed.GetRequestsTotal.Add('POST:/users:201', 2);
  THorsePrometheusExposed.GetRequestDurationSum.Add('GET:/ping', 0.15);
  THorsePrometheusExposed.GetRequestDurationCount.Add('GET:/ping', 5);

  LMetrics := THorsePrometheusExposed.CallFormatMetrics;

  AssertTrue(LMetrics.Contains('http_active_requests 3'), 'Active requests deve ser 3');
  
  // Validar formato das métricas http_requests_total
  AssertTrue(LMetrics.Contains('http_requests_total{method="GET",route="/ping",status="200"} 5'), 'Contadores do GET /ping');
  AssertTrue(LMetrics.Contains('http_requests_total{method="POST",route="/users",status="201"} 2'), 'Contadores do POST /users');

  // Validar formato das latências
  AssertTrue(LMetrics.Contains('http_request_duration_seconds_sum{method="GET",route="/ping"}'), 'Soma da duracao do GET /ping');
  AssertTrue(LMetrics.Contains('http_request_duration_seconds_count{method="GET",route="/ping"} 5'), 'Contagem da duracao do GET /ping');
end;

procedure RunAllTests;
begin
  GTestsFailed := 0;
  GTestsPassed := 0;

  try
    TestMetricsPath;
    TestFormatMetricsEmpty;
    TestFormatMetricsWithData;
  except
    on E: Exception do
    begin
      Writeln('[CRITICAL ERROR] ', E.ClassName, ': ', E.Message);
      Inc(GTestsFailed);
    end;
  end;

  Writeln('======================================');
  Writeln('Test Results:');
  Writeln('  Passed: ', GTestsPassed);
  Writeln('  Failed: ', GTestsFailed);
  Writeln('======================================');

  if GTestsFailed > 0 then
    ExitCode := 1
  else
    ExitCode := 0;
end;

end.
