defmodule PlugDatadogStats.Cowboy do
  @moduledoc """
  Cowboy-specific HTTP request metrics not covered by the more
  general base PlugDatadogStats module.
  """

  @doc """
  onresponse callback for integrating with Cowboy.
  To use, configure Plug to set this function as an
  onresponse handler for Cowboy, in config.exs:
  http: [
    protocol_options: [
      onresponse: &PlugDatadogStats.Cowboy.onresponse/4,
    ]
  ]
  """
  def onresponse(status, _headers, _body, request) do
    # Cowboy-induced HTTP 400 detection logic borrowed from Plug.
    if status == 400 and empty_headers?(request) do
      # Emit request count metric, as our usual request count metric
      # will not have fired in this case, as Cowboy decided to respond
      # with an HTTP 400, so the usual Plug request processing will not
      # have happened.
      tags = tags_for_request(status, request)
      metric_name = Application.get_env(:plug_datadog_stats, :count_name, "resp_count")
      ExStatsD.increment(metric_name, tags: tags)
    end
    request
  end

  defp empty_headers?(request) do
   {headers, _} = :cowboy_req.headers(request)
   headers == []
  end

  defp split_path(path) do
    segments = :binary.split(path, "/", [:global])
    for segment <- segments, segment != "", do: segment
  end

  defp tags_for_request(status, request) do
    {method, _} = :cowboy_req.method(request)
    {path, _} = :cowboy_req.path(request)
    path_segments = split_path(path)

    [
      "method:#{method}",
      "status:#{status}",
      "endpoint:#{PlugDatadogStats.generalize_path(path_segments)}",
    ]
  end
end
