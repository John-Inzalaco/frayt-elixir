defmodule FraytElixirWeb.Admin.MetricsView do
  use FraytElixirWeb, :view
  import FraytElixirWeb.DisplayFunctions
  import FraytElixir.Guards
  alias FraytElixir.Accounts
  alias Accounts.Company

  def company_options(companies) do
    [{"All", nil}] ++ Enum.map(companies, &{&1.name, &1.id})
  end

  def match_states(states) do
    [{"All", nil}] ++ Enum.map(states, &{humanize(&1), &1})
  end

  def display_filters(%{company_id: company_id}) when is_empty(company_id),
    do: "All Matches"

  def display_filters(%{company_id: company_id, exclude_company: exclude_company}) do
    case Accounts.get_company(company_id) do
      {:ok, company} -> display_filters(company, exclude_company)
      _ -> "N/A"
    end
  end

  def display_filters(%Company{name: name}, true), do: "Exclude #{name}'s Matches"
  def display_filters(%Company{name: name}, false), do: "Only #{name} Matches"

  def find_rep(reps, rep_id), do: Enum.find(reps, &(&1.id == rep_id))

  def display_arrows(column, order_by, :desc) when order_by == column, do: "fas fa-sort-down"
  def display_arrows(column, order_by, :asc) when order_by == column, do: "fas fa-sort-up"
  def display_arrows(_, _, _), do: "far fa-sort"

  def prev_month_revenue(nil, rep), do: prev_month_revenue(:current, rep)

  def prev_month_revenue(:current, rep),
    do:
      (Timex.today().day / (Timex.now() |> Timex.shift(months: -1) |> Timex.days_in_month()))
      |> prev_month_revenue(rep)

  def prev_month_revenue(:last, rep),
    do: prev_month_revenue(1, rep)

  def prev_month_revenue(month_progress, %{sales: sales}),
    do: round(sales * month_progress)

  def display_monthly_comparison(month_progress, %{sales: sales}, prev_rep) do
    (sales - prev_month_revenue(month_progress, prev_rep))
    |> case do
      diff when diff > 0 -> "far fa-angle-up"
      _ -> "far fa-angle-down"
    end
  end
end
