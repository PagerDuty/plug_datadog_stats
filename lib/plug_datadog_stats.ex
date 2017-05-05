defmodule PlugRequestStatsd do  
  @behaviour Plug
  import Plug.Conn, only: [register_before_send: 2]
  require Logger

  def init(_) do
    %{metric_name: get_metric_name()}
  end

  defp get_metric_name, do: Application.get_env(:plug_request_statsd, :metric_name, "resp_time")

  def call(conn, %{metric_name: metric_name}) do
    req_start_time = :os.timestamp

    register_before_send conn, fn conn ->
      tags = tags_for_conn(conn)

      # This will log response time in microseconds
      req_end_time = :os.timestamp
      duration = :timer.now_diff(req_end_time, req_start_time)

      Logger.debug("PlugRequestStatsd: #{duration}µs #{metric_name} #{inspect tags}")
      ExStatsD.histogram(duration, metric_name, tags: tags)

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
