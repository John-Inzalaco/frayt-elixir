defmodule FraytElixirWeb.LiveComponent.ContractSLAForm do
  use Phoenix.LiveComponent
  import FraytElixirWeb.Helpers.FormList
  alias FraytElixir.SLAs.ContractSLA

  def mount(socket) do
    {:ok, socket}
  end

  def update(assigns, socket) do
    use_custom? =
      case socket.assigns do
        %{use_custom?: use_custom?} -> use_custom?
        _ -> !!assigns.form
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:use_custom?, use_custom?)}
  end

  def handle_event("toggle_custom_sla", _params, %{assigns: assigns} = socket) do
    use_custom? = !assigns.use_custom?

    if use_custom? do
      send_sla_update(socket, &add_item/4, %ContractSLA{type: assigns.type})
    else
      send_sla_update(socket, &remove_item/4, assigns.form.index)
    end

    {:noreply, assign(socket, :use_custom?, use_custom?)}
  end

  def send_sla_update(socket, callback, args) do
    send(
      socket.root_pid,
      {:update_changeset, callback, [socket.assigns.root_form, :slas, args]}
    )
  end

  def render(assigns) do
    FraytElixirWeb.Admin.ContractsView.render("_contract_sla_form.html", assigns)
  end
end
