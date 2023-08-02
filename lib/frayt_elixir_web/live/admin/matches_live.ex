defmodule FraytElixirWeb.Admin.MatchesLive do
  use FraytElixirWeb, :live_view
  use FraytElixirWeb.AdminAlerts

  use FraytElixirWeb.DataTable,
    base_url: "/admin/matches",
    default_filters: %{per_page: 50},
    filters: [
      %{key: :query, type: :string, default: nil},
      %{key: :states, type: :atom, default: :active},
      %{key: :only_mine, type: :string, default: nil},
      %{key: :stops, type: :atom, default: nil},
      %{key: :start_date, type: :string, default: nil},
      %{key: :end_date, type: :string, default: nil},
      %{key: :company_id, type: :string, default: nil, when: :customer_filter},
      %{key: :contract_id, type: :string, default: nil, when: :customer_filter},
      %{key: :shipper_id, type: :string, default: nil, when: :customer_filter},
      %{key: :customer_filter, type: :atom, default: :shipper_id, stale: true},
      %{key: :driver_id, type: :string, default: nil},
      %{key: :sla, type: :atom, default: nil},
      %{key: :vehicle_class, type: :integer, default: nil}
    ],
    model: :matches

  use FraytElixirWeb.ModalEvents

  import FraytElixirWeb.DisplayFunctions,
    only: [display_date: 1]

  import Appsignal.Phoenix.LiveView, only: [live_view_action: 4]
  alias FraytElixir.Shipment
  alias FraytElixir.Accounts
  alias FraytElixir.Matches

  @enable_multistop Application.compile_env(:frayt_elixir, :enable_multistop_ui, false)

  def mount(_params, session, socket) do
    live_view_action(__MODULE__, "mount", socket, fn ->
      %{start_date: start_date, end_date: end_date} = socket.assigns.data_table.filters

      displayed_date_range =
        with {:ok, startd, _} <- DateTime.from_iso8601(start_date || ""),
             {:ok, endd, _} <- DateTime.from_iso8601(end_date || "") do
          display_date(startd) <> " - " <> display_date(endd)
        else
          _ -> nil
        end

      {:ok,
       assign(socket, %{
         show_modal: false,
         match_id: nil,
         user_id: session["current_user"].admin.id,
         displayed_date_range: displayed_date_range,
         enable_multistop: @enable_multistop,
         enterprise_companies: Accounts.list_companies(%{enterprise_only: true})
       })}
    end)
  end

  def handle_event(
        "filter_by_dates",
        %{
          "start_date" => start_date,
          "end_date" => end_date,
          "displayed_date_range" => displayed_date_range
        },
        socket
      ) do
    live_view_action(__MODULE__, "filter_by_dates", socket, fn ->
      socket =
        filters_event(socket, %{
          start_date: start_date,
          end_date: end_date
        })

      {:noreply, assign(socket, :displayed_date_range, displayed_date_range)}
    end)
  end

  def handle_event("assign_to_current_admin", %{"match_id" => match_id}, socket) do
    match = find_match(socket, match_id)

    {:noreply, assign_admin_to_match(socket, match, socket.assigns.user_id)}
  end

  def handle_event("open_assign_admin_modal", %{"match_id" => match_id}, socket) do
    match = find_match(socket, match_id)

    title =
      if match.network_operator, do: "Assign Match to Admin", else: "Reassign Match to Admin"

    modal_assigns = %{
      "match" => match,
      "title" => title
    }

    {:noreply, show_modal(socket, "AdminAssignMatch", modal_assigns)}
  end

  def handle_info({:assign_admin_to_match, match, admin_id}, socket) do
    {:noreply, assign_admin_to_match(socket, match, admin_id)}
  end

  def render(assigns) do
    FraytElixirWeb.Admin.MatchesView.render("index.html", assigns)
  end

  def list_records(socket, filters),
    do: {socket, Shipment.list_matches(filters |> Map.put(:types, :all))}

  defp assign_admin_to_match(socket, match, admin_id) do
    attrs = %{network_operator_id: admin_id}
    match = Shipment.preload_match(match)

    case Matches.update_match(match, attrs) do
      {:ok, match} -> update_match(socket, match)
      _ -> socket
    end
  end

  defp update_match(socket, updated_match) do
    matches =
      Enum.map(socket.assigns.matches, fn match ->
        if match.id == updated_match.id, do: updated_match, else: match
      end)

    assign(socket, :matches, matches)
  end

  defp find_match(socket, match_id), do: Enum.find(socket.assigns.matches, &(&1.id == match_id))
end
