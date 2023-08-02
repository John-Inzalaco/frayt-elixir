defmodule FraytElixirWeb.LiveComponent.SLAStatus do
  use Phoenix.LiveComponent
  use FraytElixirWeb.AdminAlerts

  alias FraytElixir.Shipment
  alias FraytElixir.SLAs
  alias FraytElixirWeb.Admin.MatchesView

  @default_assigns %{
    allow_update: false,
    sla: nil,
    editable?: true,
    editing_sla?: false,
    open_sla_dropdown?: false,
    showing_sla_type: nil
  }

  def mount(socket) do
    {:ok, socket |> assign(@default_assigns)}
  end

  def handle_event("recalculate_sla", _, %{assigns: %{match: match}} = socket) do
    case SLAs.calculate_match_slas(match, for: [:frayt, :driver]) do
      {:ok, match} ->
        slas = SLAs.get_active_match_slas(match)

        params = %{
          slas: slas,
          eta: Shipment.get_active_eta(match),
          showing_sla_type: if(slas, do: elem(slas, 0), else: nil)
        }

        {:noreply, assign(socket, params)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("edit_match_sla", %{"action" => action}, socket) do
    editing_sla? = action == "edit"

    # Notifies the match_id of the SLA being edited only when parent's view is
    # FraytElixirWeb.Admin.MatchesLive, which means that we're editing the SLA
    # from the matches view, not from the match details one. Notifying the match
    # id being edited is necessary to show the edition only for that match and
    # hide any other.
    if socket.view == FraytElixirWeb.Admin.MatchesLive do
      editing_match_id = if editing_sla?, do: socket.assigns.match.id

      send(self(), {:edit_match_sla, editing_match_id})
    end

    {:noreply, assign(socket, :editing_sla?, editing_sla?)}
  end

  def handle_event("toggle_sla_dropdown", _params, socket) do
    params = %{open_sla_dropdown?: !socket.assigns.open_sla_dropdown?}

    {:noreply, assign(socket, params)}
  end

  def handle_event("change_sla_type", %{"type" => type}, socket) do
    type = String.to_atom(type)
    match = socket.assigns.match
    slas = {type, get_slas_by_type(match, type)}
    params = %{open_sla_dropdown?: false, showing_sla_type: type, slas: slas}

    {:noreply, assign(socket, params)}
  end

  defp get_slas_by_type(match, type) do
    Enum.filter(match.slas, &(&1.type == type))
  end

  def update(%{match: match} = assigns, socket) do
    slas = SLAs.get_active_match_slas(match) || []

    assigns =
      assigns
      |> Map.put(:slas, slas)
      |> Map.put(:eta, Shipment.get_active_eta(match))

    {:ok, assign(socket, assigns)}
  end

  def render(assigns) do
    Phoenix.View.render(MatchesView, "_sla_progress_meters.html", assigns)
  end
end
