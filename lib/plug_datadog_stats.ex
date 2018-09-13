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

  defp generalize_path(path_info) do
    path_info
    |> Enum.map(&normalize_segment/1)
    |> Enum.join("/")
  end

  defp normalize_segment(segment) do
    cond do
      String.match?(segment, ~r/^[0-9]+$/) ->
        "INT"
      String.match?(segment, ~r/^[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}$/)  ->
        "UUID"
      String.match?(segment, ~r/^[pP]\w{6}$/) ->
        "OBFUSCATED_ID"
      String.match?(segment, ~r/^[qQ]\w{13}$/) ->
        "OBFUSCATED_ID"
      String.match?(segment, ~r/^[rR]\w{25}$/) ->
        "OBFUSCATED_ID"
      true ->
        segment
    end
  end
end
