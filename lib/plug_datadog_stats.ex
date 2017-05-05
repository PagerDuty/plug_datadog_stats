defmodule PlugDatadogStats do
  @behaviour Plug
  import Plug.Conn, only: [register_before_send: 2]
  require Logger

  def init(_) do
    %{
      histogram: Application.get_env(:plug_datadog_stats, :histogram_name, "resp_time"),
      count: Application.get_env(:plug_datadog_stats, :count_name, "resp_count"),
    }
  end

  def call(conn, names) do
    req_start_time = :os.timestamp

    register_before_send conn, fn conn ->
      tags = tags_for_conn(conn)

      # This will log response time in microseconds
      req_end_time = :os.timestamp
      duration = :timer.now_diff(req_end_time, req_start_time)

      Logger.debug("PlugDatadogStats: #{duration}µs #{names.histogram}/#{names.count} #{inspect tags}")
      ExStatsD.histogram(duration, names.histogram, tags: tags)
      ExStatsD.increment(names.count, tags: tags)

      conn
    end
  end

  defp tags_for_conn(conn) do
    [
      "method:#{conn.method}",
      "status:#{conn.status}",
      "endpoint:#{generalize_path(conn.path_info)}",
    ]
  end

  # returns the path list as a string, with numeric segment parameters filtered out. 
  # e.g. path /incidents/10/log_entries returns /incidents/log_entries
  defp generalize_path(path_info) do 
    path_info
    |> Enum.filter(fn(segment) ->
      case Integer.parse(segment) do
        :error -> true
        _ -> false
      end
    end)
    |> Enum.join("/")
  end
end
