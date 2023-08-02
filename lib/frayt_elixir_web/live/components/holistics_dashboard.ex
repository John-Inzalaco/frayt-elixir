defmodule FraytElixirWeb.LiveComponent.HolisticsDashboard do
  use Phoenix.LiveComponent
  alias FraytElixir.Holistics.HolisticsDashboard
  alias FraytElixir.Holistics

  def mount(socket) do
    {:ok,
     assign(socket,
       token: nil,
       error: nil,
       editing: false,
       changeset: nil,
       dashboard: nil,
       class: nil
     )}
  end

  def update(assigns, socket) do
    old_dashboard = socket.assigns.dashboard

    assigns =
      case assigns.dashboard do
        ^old_dashboard ->
          assigns

        %HolisticsDashboard{id: id} = dashboard when not is_nil(id) ->
          update_token(dashboard, assigns)

        _ ->
          assigns
      end

    assigns =
      if assigns.editing and is_nil(socket.assigns.changeset) do
        changeset = Holistics.change_dashboard(assigns.dashboard)
        Map.put(assigns, :changeset, changeset)
      else
        assigns
      end

    {:ok, assign(socket, assigns)}
  end

  def handle_event("edit_config", _params, socket) do
    changeset = Holistics.change_dashboard(socket.assigns.dashboard)

    {:noreply, assign(socket, editing: true, changeset: changeset)}
  end

  def handle_event("cancel_edit_config", _params, socket) do
    {:noreply, assign(socket, editing: false, changeset: nil)}
  end

  def handle_event("change_dashboard", %{"holistics_dashboard" => attrs}, socket) do
    changeset = Holistics.change_dashboard(socket.assigns.dashboard, attrs)

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("update_dashboard", %{"holistics_dashboard" => attrs}, socket) do
    assigns =
      case Holistics.upsert_dashboard(socket.assigns.dashboard, attrs) do
        {:ok, dashboard} ->
          assigns = %{changeset: nil, dashboard: dashboard, editing: false}
          update_token(dashboard, assigns)

        {:error, changeset} ->
          %{changeset: changeset}
      end

    {:noreply, assign(socket, assigns)}
  end

  def render(assigns) do
    FraytElixirWeb.Admin.ReportsView.render("_holistics_dashboard.html", assigns)
  end

  defp update_token(dashboard, assigns) do
    case Holistics.get_dashboard_embed_url(dashboard) do
      {:ok, token} ->
        assigns
        |> Map.put(:error, nil)
        |> Map.put(:token, token)

      {:error, error} ->
        assigns
        |> Map.put(:error, error)
        |> Map.put(:token, nil)
    end
  end
end
