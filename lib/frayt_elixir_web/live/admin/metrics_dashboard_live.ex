defmodule FraytElixirWeb.Admin.MetricsDashboardLive do
  use Phoenix.LiveView
  alias Timex
  alias FraytElixir.DashboardMetrics, as: Metrics

  alias FraytElixirWeb.DataTable

  import Appsignal.Phoenix.LiveView, only: [live_view_action: 4]
  import FraytElixir.Guards
  import FraytElixir.AtomizeKeys
  alias FraytElixir.Convert
  alias FraytElixir.Accounts
  alias FraytElixir.AdminSettings
  alias AdminSettings.MetricSettings
  alias FraytElixirWeb.NebulexSession

  @default_filters %{
    fulfillment: %{
      company_id: nil,
      exclude_company: false
    },
    sales: %{
      month: :current,
      order: nil,
      order_by: nil
    },
    sla: %{
      range: :today,
      state: :all,
      order: nil,
      order_by: nil
    }
  }

  @filtered_metrics Map.keys(@default_filters)

  def mount(_params, session, socket) do
    live_view_action(__MODULE__, "mount", socket, fn ->
      socket =
        assign(socket, %{
          metrics_edit: nil,
          metrics_open: nil,
          filters_edit: nil,
          enterprise_companies: Accounts.list_companies(%{enterprise_only: true}),
          states: [:completed, :canceled]
        })
        |> NebulexSession.maybe_subscribe(session)
        |> put_session_assigns(session)

      {:ok, assign(socket, get_metrics(socket))}
    end)
  end

  def handle_event("toggle_metrics_" <> metric, _event, socket) do
    live_view_action(__MODULE__, "toggle_metrics", socket, fn ->
      {:noreply,
       assign(socket, %{
         metrics_open: DataTable.toggle_show_more(socket.assigns.metrics_open, metric)
       })}
    end)
  end

  def handle_event("edit_metric_settings_" <> metric, _event, socket) do
    live_view_action(__MODULE__, "edit_metric_settings", socket, fn ->
      {:noreply, assign(socket, %{metrics_open: metric, metrics_edit: metric})}
    end)
  end

  def handle_event("update_metric_settings", %{"metric_settings_form" => settings}, socket) do
    live_view_action(__MODULE__, "update_metric_settings", socket, fn ->
      AdminSettings.change_metric_settings(sanitize_settings(settings))
      {:noreply, assign(socket, Map.merge(%{metrics_edit: nil}, get_metrics(socket, false)))}
    end)
  end

  def handle_event("edit_metric_filters_" <> metric, _event, socket) do
    live_view_action(__MODULE__, "edit_metric_filters", socket, fn ->
      {:noreply, assign(socket, %{metrics_open: metric, filters_edit: metric, metrics_edit: nil})}
    end)
  end

  def handle_event(
        "update_metric_filters",
        %{"metric_filters" => filters},
        %{assigns: %{filters_edit: metric_key}} = socket
      ) do
    live_view_action(__MODULE__, "update_metric_filters", socket, fn ->
      {:noreply, update_filters(socket, filters, metric_key, false)}
    end)
  end

  def handle_event("cancel_edit", _, socket) do
    live_view_action(__MODULE__, "cancel_edit", socket, fn ->
      {:noreply, assign(socket, %{metrics_edit: nil, filters_edit: nil})}
    end)
  end

  def handle_event("sales_month_" <> month, _, socket) when month in ["last", "current"] do
    live_view_action(__MODULE__, "sales_month_#{month}", socket, fn ->
      {:noreply, update_filters(socket, %{month: String.to_existing_atom(month)}, :sales)}
    end)
  end

  def handle_event("sla_range_" <> range, _, socket) when range in ["month", "today"] do
    live_view_action(__MODULE__, "sla_range_#{range}", socket, fn ->
      {:noreply, update_filters(socket, %{range: String.to_existing_atom(range)}, :sla)}
    end)
  end

  def handle_event(
        "sales_reps_order_by_" <> field,
        _,
        %{assigns: %{filters: %{sales: filters}}} = socket
      )
      when field in ["goal", "progress"] do
    live_view_action(__MODULE__, "sales_reps_order_by_#{field}", socket, fn ->
      order_by = String.to_existing_atom(field)

      {order_by, order} =
        case filters do
          %{order: :asc, order_by: ^order_by} -> {nil, nil}
          %{order: :desc, order_by: ^order_by} -> {order_by, :asc}
          _ -> {order_by, :desc}
        end

      {:noreply, update_filters(socket, %{order_by: order_by, order: order}, :sales)}
    end)
  end

  def handle_event(
        "sla_order_by_" <> field,
        _,
        %{assigns: %{filters: %{sla: filters}}} = socket
      )
      when field in ["value"] do
    live_view_action(__MODULE__, "sla_order_by_#{field}", socket, fn ->
      order_by = String.to_existing_atom(field)

      {order_by, order} =
        case filters do
          %{order: :asc, order_by: ^order_by} -> {nil, nil}
          %{order: :desc, order_by: ^order_by} -> {order_by, :asc}
          _ -> {order_by, :desc}
        end

      {:noreply, update_filters(socket, %{order_by: order_by, order: order}, :sla)}
    end)
  end

  def handle_event("refresh_metrics", _event, socket) do
    live_view_action(__MODULE__, "refresh_metrics", socket, fn ->
      {:noreply, assign(socket, get_metrics(socket, false))}
    end)
  end

  def handle_info({:live_session_updated, session}, socket) do
    {:noreply, put_session_assigns(socket, session)}
  end

  def render(assigns) do
    FraytElixirWeb.Admin.MetricsView.render("dashboard.html", assigns)
  end

  defp put_session_assigns(socket, session) do
    filters =
      Map.get(session, "metric_filters", %{})
      |> sanitize_filters()

    assign(
      socket,
      :filters,
      @default_filters
      |> Enum.map(fn {metric, metric_filters} ->
        {metric, metric_filters |> Map.merge(Map.get(filters, metric, %{}))}
      end)
      |> Enum.into(%{})
    )
  end

  defp update_filters(socket, filters, metric_key, use_cache \\ true)

  defp update_filters(socket, filters, metric_key, use_cache) when is_binary(metric_key),
    do: update_filters(socket, filters, String.to_existing_atom(metric_key), use_cache)

  defp update_filters(socket, metric_filters, metric_key, use_cache)
       when metric_key in @filtered_metrics do
    filters =
      sanitize_filters(
        socket.assigns.filters
        |> Map.put(
          metric_key,
          socket.assigns.filters[metric_key]
          |> Map.merge(atomize_keys(metric_filters))
        )
      )

    NebulexSession.put_session(socket, "metric_filters", filters)

    socket =
      assign(socket, %{
        filters_edit: nil,
        filters: filters
      })

    assign(socket, get_metrics(socket, use_cache))
  end

  defp sanitize_filters(filters) do
    filters = filters |> atomize_keys()

    @filtered_metrics
    |> Enum.map(fn metric_key ->
      filter_keys = Map.keys(@default_filters[metric_key])

      {metric_key,
       Enum.map(filter_keys, fn filter_key ->
         sanitize_filter(filter_key, filters[metric_key][filter_key])
       end)
       |> Enum.into(%{})}
    end)
    |> Enum.into(%{})
  end

  defp sanitize_filter(:exclude_company, value) when is_binary(value),
    do: {:exclude_company, value == "true"}

  defp sanitize_filter(key, value), do: {key, value}

  defp get_metrics(
         %{
           assigns: %{
             filters: %{
               fulfillment: fulfillment_filters,
               sales: sales_filters,
               sla: sla_filters
             }
           }
         },
         use_cache \\ true
       ) do
    %MetricSettings{
      fulfillment_goal: fulfillment_goal,
      monthly_revenue_goal: monthly_revenue_goal,
      sla_goal: sla_goal
    } = AdminSettings.get_metric_settings()

    now = NaiveDateTime.utc_now()
    last_month = Metrics.last_month(now)
    opts = [use_cache: use_cache]

    %{
      this_month: Timex.month_name(now.month),
      last_month: Timex.month_name(last_month.month),
      days_in_month: Timex.days_in_month(now.year, now.month),
      sales: get_sales_metrics(sales_filters, now, opts),
      fulfillment:
        get_fulfillment_metrics(
          fulfillment_goal,
          fulfillment_filters,
          now,
          opts
        ),
      revenue: %{
        goal: monthly_revenue_goal,
        this_month: Metrics.get_metric_value(:admin_metric_monthly_revenue, now, opts),
        last_month: Metrics.get_metric_value(:admin_metric_last_month_revenue, now, opts)
      },
      sla: get_sla_ratings(sla_goal, sla_filters, now, use_cache: false),
      matches_in_progress: Metrics.get_metric_value(:admin_metric_matches_in_progress, now, opts),
      matches_this_month: Metrics.get_metric_value(:admin_metric_matches_this_month, now, opts),
      matches_unassigned: Metrics.get_metric_value(:admin_metric_matches_unassigned, now, opts),
      average_match_time: Metrics.get_metric_value(:admin_metric_match_average_time, now, opts),
      metrics_last_run: get_metrics_last_run(use_cache, :metrics_updated_at)
    }
  end

  defp get_sales_metrics(%{month: month, order: order, order_by: order_by}, now, opts) do
    month = month || :current

    %{
      current:
        case month do
          :current ->
            Metrics.get_metric_value(:admin_metric_sales_goals_current, now, opts)
            |> order_result(order_by, order)

          :last ->
            Metrics.get_metric_value(:admin_metric_sales_goals_1_month_ago, now, opts)
            |> order_result(order_by, order)
        end,
      last:
        case month do
          :current ->
            Metrics.get_metric_value(:admin_metric_sales_goals_1_month_ago, now, opts)

          :last ->
            Metrics.get_metric_value(:admin_metric_sales_goals_2_months_ago, now, opts)
        end
    }
  end

  defp get_fulfillment_metrics(goal, %{company_id: company_id}, now, opts)
       when is_empty(company_id) do
    %{
      goal: goal,
      this_month: Metrics.get_metric_value(:admin_metric_fulfillment_this_month, now, opts),
      today: Metrics.get_metric_value(:admin_metric_fulfillment_today, now, opts)
    }
  end

  defp get_fulfillment_metrics(
         goal,
         %{company_id: company_id, exclude_company: true},
         now,
         opts
       ) do
    this_month =
      Metrics.get_metric_value(:admin_metric_fulfillment_this_month, now, opts)
      |> exclude_company_fulfillment(
        Metrics.get_metric_value("admin_metric_fulfillment_this_month_#{company_id}", now, opts)
      )

    today =
      Metrics.get_metric_value(:admin_metric_fulfillment_today, now, opts)
      |> exclude_company_fulfillment(
        Metrics.get_metric_value("admin_metric_fulfillment_today_#{company_id}", now, opts)
      )

    %{
      goal: goal,
      this_month: this_month,
      today: today
    }
  end

  defp get_fulfillment_metrics(
         goal,
         %{company_id: company_id, exclude_company: false},
         now,
         opts
       ) do
    %{
      goal: goal,
      this_month:
        Metrics.get_metric_value("admin_metric_fulfillment_this_month_#{company_id}", now, opts),
      today: Metrics.get_metric_value("admin_metric_fulfillment_today_#{company_id}", now, opts)
    }
  end

  defp get_sla_ratings(goal, filters, now, opts) do
    %{order: order, order_by: order_by, range: range, state: state} = filters
    range = range || "today"
    state = if is_nil(state) || state == "", do: "all", else: state
    metric_key = "admin_metric_sla_#{state}_#{range}"
    details = Metrics.get_metric_value(metric_key, now, opts)

    {on_time, total} =
      Enum.reduce(details, {0, 0}, fn d, {on_time, total} ->
        {on_time + d.on_time, total + d.total}
      end)

    overall_rating = %{
      company: "All",
      value: if(total > 0, do: on_time / total, else: 0)
    }

    company_ratings =
      Enum.map(details, fn %{company: comp, total: total, on_time: ot} ->
        %{company: comp, value: if(total > 0, do: ot / total, else: 0)}
      end)

    ratings = [overall_rating | order_result(company_ratings, order_by, order)]

    %{goal: goal, ratings: ratings}
  end

  defp order_result(res, order_by, order) when not is_nil(order) and not is_nil(order_by),
    do: res |> Enum.sort_by(&(&1[order_by] || -1), order)

  defp order_result(res, _, _), do: res

  defp exclude_company_fulfillment(all, company),
    do:
      Metrics.calculate_fulfillment({
        all.completed - company.completed,
        all.canceled - company.canceled,
        all.attempted - company.attempted,
        all.total - company.total
      })

  defp get_metrics_last_run(true, key) do
    case Metrics.get_cached_value(key) do
      {:ok, time} -> format_time(time)
      _ -> nil
    end
  end

  defp get_metrics_last_run(false, _),
    do: NaiveDateTime.utc_now() |> format_time()

  defp format_time(datetime) do
    case Timex.format(datetime, "{relative}", :relative) do
      {:ok, time_ago} -> time_ago
      _ -> nil
    end
  end

  defp sanitize_settings(%{"monthly_revenue_goal" => goal} = settings),
    do: %{settings | "monthly_revenue_goal" => round(Convert.to_float(goal) * 100)}

  defp sanitize_settings(settings), do: settings
end
