defmodule FraytElixirWeb.LiveComponent.EditMatchSlaTimestamp do
  use Phoenix.LiveComponent

  alias FraytElixir.Repo
  alias FraytElixir.SLAs

  @time_types %{
    start_time: "Start",
    end_time: "End",
    completed_at: "Completed"
  }

  def mount(socket) do
    assigns = %{show?: false, type: :start_time, time_types: @time_types}

    {:ok, assign(socket, assigns)}
  end

  def update(assigns, socket) do
    changeset = SLAs.change_match_sla(assigns.sla, %{})
    assigns = Map.put(assigns, :changeset, changeset)

    {:ok, assign(socket, assigns)}
  end

  def handle_event("update_time", _attrs, socket) do
    case Repo.update(socket.assigns.changeset) do
      {:ok, sla} ->
        send(self(), {:match_sla_updated, sla})
        changeset = SLAs.change_match_sla(sla, %{})

        {:noreply, assign(socket, sla: sla, changeset: changeset)}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  def handle_event("change_time", %{"match_sla" => attrs}, socket) do
    changeset = SLAs.change_match_sla(socket.assigns.sla, attrs)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("toggle_dropdown", _, socket) do
    {
      :noreply,
      assign(socket, %{show?: !socket.assigns.show?})
    }
  end

  def handle_event("change_time_type", %{"type" => type}, socket) do
    {:noreply, assign(socket, %{show?: false, type: String.to_atom(type)})}
  end

  def render(assigns) do
    FraytElixirWeb.Admin.MatchesView.render("_edit_match_sla.html", assigns)
  end
end
