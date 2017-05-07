defmodule PlugDatadogStats.Mixfile do
  use Mix.Project

  def project do
    [app: :plug_datadog_stats,
     version: "2.0.1",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [
      extra_applications: [
        :logger,
        :ex_statsd,
      ],
    ]
  end

  defp deps do
    [
      {:ex_statsd, github: "PagerDuty/ex_statsd", ref: "a5c1aefd1d8d273e3910c2ae53c034669f792400"}, # Pulling in Cees' socket open fix
      {:plug, "~> 1.3.2"},
    ]
  end
end
