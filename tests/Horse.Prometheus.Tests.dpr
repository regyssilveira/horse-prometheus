program Horse.Prometheus.Tests;

{$IFNDEF FPC}
  {$APPTYPE CONSOLE}
{$ENDIF}

uses
  {$IFDEF FPC}
  SysUtils,
  {$ELSE}
  System.SysUtils,
  {$ENDIF}
  Horse.Prometheus.Tests.Cases in 'Horse.Prometheus.Tests.Cases.pas';

begin
  try
    RunAllTests;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
