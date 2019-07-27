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

### Some Potential Approaches

#### Anonymous function

This requires the most work from the user of the plug.  However I think this should likely
be the approach we take until we hear that many people are running in to this issue.

```elixir
# The function should return a list in the shape of
# conn.path_info but with fields removed for dd tags
# Example: ["api", "v1", "status_service", "slug", "OBFUSCATED"]

pre_plug PlugDatadogStats, path_normalize_fn: fn
  ["api", "v1", "status_service", "slug", slug_one, "views", slug_two] = path ->
    path
    |> Enum.map(fn 
      ^slug_one ->
        "SLUG"

      ^slug_two ->
        "OTHER_SLUG"

      segment ->
        segment
      end
    )

  path ->
    path
end
```

#### Override Through `assigns`

This is similar to the above function but we leave it up to the user
to figure out how to generate that data structure.  One piece of this that could
change would be that we'd just require them to add it under a certain key in `assigns`
rather than letting them specify their own.

```elixir
# User writes another plug (or otherwise modifies conn.assigns).  It should add
# something under a key in assigns that is a list mirroring the
# shape of conn.path_info but with fields removed for dd tags
# Example: ["api", "v1", "status_service", "slug", "OBFUSCATED"]

pre_plug PathParamOverride 
pre_plug PlugDatadogStats, path_info_override: :dd_path_tag_override # :dd_path_tag_override was added to the assigns by PathParamOverride
```

#### Metaprogramming Madness (MM)

This approach would take in a pattern as shown below, and autogenerate matchers within the plug
to normalize requests matching the patter.  This would require some metaprogramming in the plug
but would require the least knowledge from the user of the library about the inner workings
of the library.

```elixir
# Metaprogramming in the plug generates methods that do something similar to the first example
pre_plug PlugDatadogStats, normalize_patterns: [
  ["api", "v1", "status_service", "slug", {:replace, "SLUG"}],
  ["api", "v1", "status_service", "slug", {:replace, "SLUG"}, "views", {:replace, "OTHER_SLUG"}]
]
```
