defmodule PlugDatadogStats do
  @behaviour Plug
  import Plug.Conn, only: [register_before_send: 2, put_private: 3]
  require Logger

  @base_opts %{
    histogram: Application.get_env(:plug_datadog_stats, :histogram_name, "resp_time"),
    count: Application.get_env(:plug_datadog_stats, :count_name, "resp_count"),
    path_normalize_fn: {__MODULE__, :path_override_passthrough, []}
  }

  def init(opts \\ []) do
    opts
    |> Enum.into(@base_opts)
    |> parse_options()
  end

  def call(conn, opts) do
    req_start_time = :os.timestamp()

    register_before_send(conn, fn conn ->
      # This will log response time in microseconds
      req_end_time = :os.timestamp()
      duration = :timer.now_diff(req_end_time, req_start_time)

      tags = tags_for_conn(conn, opts.path_normalize_fn)

      Logger.debug(
        "PlugDatadogStats: #{duration}µs #{opts.histogram}/#{opts.count} #{inspect(tags)}"
      )

      ExStatsD.histogram(duration, opts.histogram, tags: tags)
      ExStatsD.increment(opts.count, tags: tags)

      # Tags are added to the conn for testing and observability purposes
      put_private(conn, :plug_datadog_stats_tags, tags)
    end)
  end

  defp parse_options(%{path_normalize_fn: {_m, _f, _a}} = opts) do
    opts
  end

  defp parse_options(%{path_normalize_fn: _bad}) do
    raise """
      The path_normalize_fn option should be provided in the format {module, function, arguments}.

      Example: PlugDatadogStats, path_normalize_fn: {MyModule, :function_name, []}
    """
  end

  defp parse_options(opts), do: opts

  defp tags_for_conn(conn, path_normalize_fn) do
    path_for_tag = generalize_path(conn.path_info, path_normalize_fn)

    [
      "method:#{conn.method}",
      "status:#{conn.status}",
      "endpoint:#{path_for_tag}"
    ]
  end

  defp generalize_path(path_info, path_normalize_fn) do
    path_info
    |> apply_path_normalize_fn(path_normalize_fn)
    |> Enum.map(&normalize_segment/1)
    |> Enum.join("/")
  end

  defp normalize_segment(segment) do
    cond do
      String.match?(segment, ~r/^[0-9]+$/) ->
        "INT"

      String.match?(segment, ~r/^[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}$/) ->
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

  defp apply_path_normalize_fn(path_info, {m, f, a}) do
    apply(m, f, [path_info | a])
  end

  def path_override_passthrough(path_info) do
    path_info
  end
end
