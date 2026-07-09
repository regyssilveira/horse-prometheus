program Sample;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Horse,
  Horse.Prometheus;

begin
  // Registra o middleware do Prometheus com parenteses explicitos
  THorse.Use(THorsePrometheus.Middleware());

  THorse.Get('/ping',
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    begin
      Res.Send('pong');
    end);

  THorse.Get('/users',
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    begin
      Res.Send('[{"id": 1, "name": "Arthur"}, {"id": 2, "name": "Ford"}]');
    end);

  THorse.Post('/users',
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    begin
      Res.Send('User created').Status(201);
    end);

  Writeln('Servidor de teste Prometheus rodando em:');
  Writeln('  - API: http://localhost:9000/ping');
  Writeln('  - Metricas: http://localhost:9000/metrics');
  THorse.Listen(9000);
end.
