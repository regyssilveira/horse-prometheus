program Sample;

{$MODE DELPHI}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  SysUtils,
  Horse,
  Horse.Prometheus;

procedure GetPing(Req: THorseRequest; Res: THorseResponse; Next: TNextProc);
begin
  Res.Send('pong');
end;

procedure GetUsers(Req: THorseRequest; Res: THorseResponse; Next: TNextProc);
begin
  Res.Send('[{"id": 1, "name": "Arthur"}, {"id": 2, "name": "Ford"}]');
end;

procedure PostUsers(Req: THorseRequest; Res: THorseResponse; Next: TNextProc);
begin
  Res.Send('User created').Status(201);
end;

begin
  // Registra o middleware do Prometheus
  THorse.Use(THorsePrometheus.Middleware);

  THorse.Get('/ping', GetPing);
  THorse.Get('/users', GetUsers);
  THorse.Post('/users', PostUsers);

  Writeln('Servidor de teste Prometheus rodando em:');
  Writeln('  - API: http://localhost:9000/ping');
  Writeln('  - Metricas: http://localhost:9000/metrics');
  THorse.Listen(9000);
end.
