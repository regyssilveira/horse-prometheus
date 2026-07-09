# horse-prometheus

Prometheus middleware for **Horse**.

Allows you to monitor your Delphi APIs using Prometheus and Grafana.

## ⚙️ Installation

Use the [Boss](https://github.com/HashLoad/boss) package manager:

```sh
boss install horse-prometheus
```

## ⚡️ Quick Start

```delphi
uses
  Horse,
  Horse.Prometheus;

begin
  // Register the Prometheus middleware
  THorse.Use(THorsePrometheus.Middleware);

  THorse.Get('/ping',
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    begin
      Res.Send('pong');
    end);

  THorse.Listen(9000);
end.
```

Your metrics will be automatically exposed at the `http://localhost:9000/metrics` endpoint in Prometheus format.

## 🔧 Configuration

You can customize the metrics path (default is `/metrics`):

```delphi
THorsePrometheus.SetMetricsPath('custom-metrics-path');
```
