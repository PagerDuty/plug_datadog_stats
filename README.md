# PlugDatadogStats

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
    {:plug_datadog_stats, github: "PagerDuty/plug_datadog_stats", ref: "1.0.0"},
  ]
end
```

In your `config.exs`:

```elixir
config :plug_datadog_stats,
  histogram_name: "whatever.you.want.in.datadog.resp_time",
  count_name: "whatever.you.want.in.datadog.resp_count"

# Configure ExStatsD as per the ExStatsD docs.
```

And then e.g. in a Phoenix `your_plug_based_thing/endpoint.ex`:

```elixir
defmodule YourPlugBasedThing.Endpoint do
  ...
  pre_plug PlugDatadogStats
  ...
end
```

## Handling Non-standard Path Parameters

Sometimes we have paths that have path parameters that are not easily
matchable using regular expressions.

A simple example would be this:
`/api/v1/status_service/slug/my-custom-slug-4`

A more complex example might look like this:
`/api/v1/status_service/slug/my-custom-slug-4/views/my-user-readable-view-id`

`PlugDatadogStats` will interpret each of these as a separate path and create a tag
for all of them which is Not Desirable™.

To handle cases like this, you can pass the plug a `path_normalize_fn`
option that explicitly matches on the path patterns you expect:

```elixir
# This can be defined in any other module.  For this example it is defined in the
# same module that the plug is added to the pipeline
def path_param_override(["api", "v1", "status_service", "slug", _slug]) do
  ["api", "v1", "status_service", "slug", "SLUG"]
end

def path_param_override(path_info), do: path_info # be sure to include the base case

pre_plug PlugDatadogStats, path_normalize_fn: {__MODULE__, :path_param_override, []}
```
