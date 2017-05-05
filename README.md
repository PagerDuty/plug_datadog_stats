# PlugRequestStatsd

Provides a pre-plug to log request time, status, and integer-ignoring-URL-path
to datadog.

## Installation

You can install the plug directly from GitHub with these incantations in your `mix.exs`:

```elixir
def application do
  [
    mod: {YourPlugBasedThing, []},
    applications: [
      ...
      :pre_plug,
    ]
  ]
end

def deps do
  [
    {:pre_plug, "~> 0.1.0"},
    {:plug_request_statsd, github: "PagerDuty/plug_request_statsd", ref: "0.1.0"},
  ]
end
```

In your `config.exs`:

```elixir
config :plug_request_statsd, metric_name: "whatever.you.want.in.datadog.resp_time"

# Configure ExStatsD as per the ExStatsD docs.
```

And then e.g. in a Phoenix `your_plug_based_thing/endpoint.ex`:

```elixir
defmodule YourPlugBasedThing.Endpoint do
  ...
  pre_plug PlugRequestStatsd
  ...
end
```
