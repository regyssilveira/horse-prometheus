unit Horse.Prometheus;

{$IF DEFINED(FPC)}
  {$MODE DELPHI}{$H+}
{$ENDIF}

interface

uses
  {$IF DEFINED(FPC)}
    SysUtils, Classes, Generics.Collections, SyncObjs,
  {$ELSE}
    System.StringHelper, System.SysUtils, System.Classes, System.Generics.Collections, System.SyncObjs,
  {$ENDIF}
  Horse;

type
  THorsePrometheus = class
  strict private
    class var FLock: TCriticalSection;
    class var FRequestsTotal: TDictionary<string, Int64>;
    class var FRequestDurationSum: TDictionary<string, Double>;
    class var FRequestDurationCount: TDictionary<string, Int64>;
    class var FActiveRequests: Integer;
    class var FMetricsPath: string;
    class function FormatMetrics: string;
  public
    class constructor Create;
    class destructor Destroy;
    class function GetMetricsPath: string; static;
    class procedure SetMetricsPath(const AValue: string); static;
    class function Middleware: THorseCallback;
  end;

implementation

{ THorsePrometheus }

class constructor THorsePrometheus.Create;
begin
  FLock := TCriticalSection.Create;
  FRequestsTotal := TDictionary<string, Int64>.Create;
  FRequestDurationSum := TDictionary<string, Double>.Create;
  FRequestDurationCount := TDictionary<string, Int64>.Create;
  FActiveRequests := 0;
  FMetricsPath := '/metrics';
end;

class destructor THorsePrometheus.Destroy;
begin
  FRequestsTotal.Free;
  FRequestDurationSum.Free;
  FRequestDurationCount.Free;
  FLock.Free;
end;

class function THorsePrometheus.GetMetricsPath: string;
begin
  Result := FMetricsPath;
end;

class procedure THorsePrometheus.SetMetricsPath(const AValue: string);
begin
  FMetricsPath := '/' + AValue.Trim(['/']);
end;

class function THorsePrometheus.FormatMetrics: string;
var
  LSB: TStringBuilder;
  LPairTotal: TPair<string, Int64>;
  LPairDuration: TPair<string, Double>;
  LKey: string;
  LParts: TArray<string>;
  LMethod, LRoute, LStatus: string;
begin
  LSB := TStringBuilder.Create;
  try
    FLock.Enter;
    try
      // HELP e TYPE para http_requests_total
      LSB.AppendLine('# HELP http_requests_total Total number of HTTP requests processed.');
      LSB.AppendLine('# TYPE http_requests_total counter');
      for LPairTotal in FRequestsTotal do
      begin
        LKey := LPairTotal.Key;
        LParts := LKey.Split([':']);
        if Length(LParts) = 3 then
        begin
          LMethod := LParts[0];
          LRoute := LParts[1];
          LStatus := LParts[2];
          LSB.AppendLine(Format('http_requests_total{method="%s",route="%s",status="%s"} %d', [LMethod, LRoute, LStatus, LPairTotal.Value]));
        end;
      end;

      // HELP e TYPE para http_request_duration_seconds
      LSB.AppendLine('# HELP http_request_duration_seconds HTTP request latencies in seconds.');
      LSB.AppendLine('# TYPE http_request_duration_seconds summary');
      for LPairDuration in FRequestDurationSum do
      begin
        LKey := LPairDuration.Key;
        LParts := LKey.Split([':']);
        if Length(LParts) = 2 then
        begin
          LMethod := LParts[0];
          LRoute := LParts[1];
          LSB.AppendLine(Format('http_request_duration_seconds_sum{method="%s",route="%s"} %f', [LMethod, LRoute, LPairDuration.Value]));
          if FRequestDurationCount.ContainsKey(LKey) then
            LSB.AppendLine(Format('http_request_duration_seconds_count{method="%s",route="%s"} %d', [LMethod, LRoute, FRequestDurationCount.Items[LKey]]));
        end;
      end;

      // HELP e TYPE para http_active_requests
      LSB.AppendLine('# HELP http_active_requests Number of currently active HTTP requests.');
      LSB.AppendLine('# TYPE http_active_requests gauge');
      LSB.AppendLine(Format('http_active_requests %d', [FActiveRequests]));
    finally
      FLock.Leave;
    end;
    Result := LSB.ToString;
  finally
    LSB.Free;
  end;
end;

class function THorsePrometheus.Middleware: THorseCallback;
begin
  Result :=
    procedure(Req: THorseRequest; Res: THorseResponse; Next: {$IF DEFINED(FPC)}TNextProc{$ELSE}TProc{$ENDIF})
    var
      LStartTime: Int64;
      LEndTime: Int64;
      LElapsedSeconds: Double;
      LPath: string;
      LMethod: string;
      LRoute: string;
      LStatusStr: string;
      LMetricKeyTotal: string;
      LMetricKeyDuration: string;
      LCount: Int64;
    begin
      LPath := Req.PathInfo;
      LMethod := Req.Method;

      // Intercepta e serve o endpoint de métricas diretamente
      if SameText(LPath, FMetricsPath) then
      begin
        Res.Send(FormatMetrics).Status(200).ContentType('text/plain; version=0.0.4');
        Exit;
      end;

      FLock.Enter;
      try
        Inc(FActiveRequests);
      finally
        FLock.Leave;
      end;

      LStartTime := TThread.GetTickCount64;
      try
        Next();
      finally
        LEndTime := TThread.GetTickCount64;
        LElapsedSeconds := (LEndTime - LStartTime) / 1000.0;

        FLock.Enter;
        try
          Dec(FActiveRequests);

          LRoute := Req.MatchedRoute;
          if LRoute = '' then
            LRoute := LPath; // Fallback se não casou rota específica

          LStatusStr := Res.Status.ToString;

          // Incrementa total de requisições
          LMetricKeyTotal := LMethod + ':' + LRoute + ':' + LStatusStr;
          if FRequestsTotal.TryGetValue(LMetricKeyTotal, LCount) then
            FRequestsTotal.AddOrSetValue(LMetricKeyTotal, LCount + 1)
          else
            FRequestsTotal.Add(LMetricKeyTotal, 1);

          // Incrementa soma de duração e contagem
          LMetricKeyDuration := LMethod + ':' + LRoute;
          if FRequestDurationSum.ContainsKey(LMetricKeyDuration) then
          begin
            FRequestDurationSum.AddOrSetValue(LMetricKeyDuration, FRequestDurationSum.Items[LMetricKeyDuration] + LElapsedSeconds);
            FRequestDurationCount.AddOrSetValue(LMetricKeyDuration, FRequestDurationCount.Items[LMetricKeyDuration] + 1);
          end
          else
          begin
            FRequestDurationSum.Add(LMetricKeyDuration, LElapsedSeconds);
            FRequestDurationCount.Add(LMetricKeyDuration, 1);
          end;
        finally
          FLock.Leave;
        end;
      end;
    end;
end;

end.
