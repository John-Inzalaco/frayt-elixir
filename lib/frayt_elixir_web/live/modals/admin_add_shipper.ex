defmodule FraytElixirWeb.AdminAddShipper do
  use Phoenix.LiveView

  alias FraytElixir.Accounts
  alias FraytElixir.Accounts.Shipper

  import FraytElixir.AtomizeKeys

  @empty_shipper_changeset Shipper.changeset(%Shipper{address: nil}, %{})
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket, %{
       changeset: @empty_shipper_changeset,
       shipper_state: nil,
       shipper_id: nil
     })}
  end

  def handle_event("close_modal", _event, socket) do
    send(socket.parent_pid, :close_modal)
    {:noreply, socket}
  end

  def handle_event("save_shipper", %{"shipper" => form}, socket) do
    new_shipper_attrs = atomize_keys(form)

    case Accounts.create_shipper(new_shipper_attrs) do
      {:ok, _} ->
        assign(socket, %{changeset: @empty_shipper_changeset})
        send(socket.parent_pid, :shippers_updated)
        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def render(assigns) do
    FraytElixirWeb.Admin.ShippersView.render("add_shipper.html", assigns)
  end
end
