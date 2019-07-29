defmodule PlugDatadogStatsTest do
  use ExUnit.Case
  use Plug.Test
  alias Plug.Conn

  defmodule PathInfoToTags do
    def normalize do
      :ok
    end
  end

  describe "generated tags" do
    test "generates the expected tags for a basic path request" do
      conn =
        %Conn{method: "GET", status: 200, path_info: ["api", "v1", "status_views"]}
        |> PlugDatadogStats.call(PlugDatadogStats.init([]))

      [before_send_fn] = conn.before_send

      assert %{
               private: %{
                 plug_datadog_stats_tags: [
                   "method:GET",
                   "status:200",
                   "endpoint:api/v1/status_views"
                 ]
               }
             } = before_send_fn.(conn)
    end

    test "generates the expected tags for an unpredictable path param" do
      defmodule MyOverrideTest do
        def define_overrides(["api", "v1", "status_views", _slug]) do
          ["api", "v1", "status_views", "SLUG"]
        end

        def define_overrides(path_info), do: path_info
      end

      conn =
        %Conn{
          method: "GET",
          status: 200,
          path_info: ["api", "v1", "status_views", "big-strong-bear"]
        }
        |> PlugDatadogStats.call(
          PlugDatadogStats.init(path_normalize_fn: {MyOverrideTest, :define_overrides, []})
        )

      [before_send_fn] = conn.before_send

      assert %{
               private: %{
                 plug_datadog_stats_tags: [
                   "method:GET",
                   "status:200",
                   "endpoint:api/v1/status_views/SLUG"
                 ]
               }
             } = before_send_fn.(conn)
    end

    test "generates the expected tags for multiple unpredictable path params" do
      defmodule MyOverrideTest do
        def define_overrides(["api", "v1", "status_views", _slug, "owner_name", _owner_slug]) do
          ["api", "v1", "status_views", "SLUG", "owner_name", "OWNER_SLUG"]
        end

        def define_overrides(path_info), do: path_info
      end

      conn =
        %Conn{
          method: "GET",
          status: 200,
          path_info: ["api", "v1", "status_views", "big-strong-bear", "owner_name", "mr-steve"]
        }
        |> PlugDatadogStats.call(
          PlugDatadogStats.init(path_normalize_fn: {MyOverrideTest, :define_overrides, []})
        )

      [before_send_fn] = conn.before_send

      assert %{
               private: %{
                 plug_datadog_stats_tags: [
                   "method:GET",
                   "status:200",
                   "endpoint:api/v1/status_views/SLUG/owner_name/OWNER_SLUG"
                 ]
               }
             } = before_send_fn.(conn)
    end

    test "leaves a path that does not match the pattern alone" do
      defmodule MyOverrideTest do
        def define_overrides(["api", "v1", "status_views", _slug]) do
          ["api", "v1", "status_views", "SLUG"]
        end

        def define_overrides(path_info), do: path_info
      end

      conn =
        %Conn{
          method: "GET",
          status: 200,
          path_info: ["api", "v1", "status_views", "active", "mine"]
        }
        |> PlugDatadogStats.call(
          PlugDatadogStats.init(path_normalize_fn: {MyOverrideTest, :define_overrides, []})
        )

      [before_send_fn] = conn.before_send

      assert %{
               private: %{
                 plug_datadog_stats_tags: [
                   "method:GET",
                   "status:200",
                   "endpoint:api/v1/status_views/active/mine"
                 ]
               }
             } = before_send_fn.(conn)
    end
  end

  describe "path_normalize_fn as mfa" do
    test "consumes without error" do
      assert %{
               histogram: histogram_config,
               count: count_config,
               path_normalize_fn: {PathInfoToTags, :normalize, []}
             } = PlugDatadogStats.init(path_normalize_fn: {PathInfoToTags, :normalize, []})
    end
  end

  describe "path_normalize_fn is other type" do
    test "won't compile" do
      assert_raise RuntimeError, ~r/should be provided in the format \{module, function, arguments\}/, fn ->
        defmodule BadModule do
          @opts PlugDatadogStats.init(path_normalize_fn: fn -> :ok end)
        end
      end
    end
  end

  describe "no options" do
    test "intializes without error with no app-specific config" do
      assert %{
               histogram: "resp_time",
               count: "resp_count"
             } = PlugDatadogStats.init()
    end
  end
end
