defmodule FraytElixirWeb.Admin.ShippersLive do
  use FraytElixirWeb, :live_view

  use FraytElixirWeb.DataTable,
    base_url: "/admin/shippers",
    default_filters: %{order_by: :updated_at},
    filters: [
      %{key: :query, type: :string, default: nil},
      %{key: :role, type: :atom, default: nil},
      %{key: :company_id, type: :string, default: nil},
      %{key: :sales_rep_id, type: :string, default: nil},
      %{key: :state, type: :string, default: nil}
    ],
    model: :shippers

  use FraytElixirWeb.ModalEvents
  alias FraytElixir.Accounts
  alias FraytElixir.Accounts.Shipper
  import FraytElixir.AtomizeKeys

  @empty_shipper_changeset Shipper.changeset(%Shipper{address: nil}, %{})

  def mount(_params, _session, socket) do
    live_view_action(__MODULE__, "mount", socket, fn ->
      {:ok,
       assign(socket, %{
         title: nil,
         show_modal: false,
         editable_id: nil,
         shipper_id: nil,
         shipper_state: nil,
         shipper_changeset: @empty_shipper_changeset
       })}
    end)
  end

  def handle_event("edit" <> shipper_id, _, socket) do
    live_view_action(__MODULE__, "edit_shipper", socket, fn ->
      shipper = Enum.find(socket.assigns.shippers, &(&1.id == shipper_id))
      shipper_changeset = Shipper.update_changeset(shipper, %{})

      {:noreply,
       socket
       |> assign_data_table(:show_more, shipper_id)
       |> assign(%{
         editable_id: shipper_id,
         shipper_changeset: shipper_changeset
       })}
    end)
  end

  def handle_event("cancel_edit_shipper", _, socket) do
    live_view_action(__MODULE__, "cancel_edit_shipper", socket, fn ->
      {:noreply, assign(socket, %{editable_id: nil, shipper_changeset: @empty_shipper_changeset})}
    end)
  end

  def handle_event("update_shipper_state", %{"update_shipper_state" => form}, socket) do
    %{
      "shipper_id" => shipper_id,
      "state" => state
    } = form

    shipper = Accounts.get_shipper!(shipper_id)

    title =
      cond do
        state == "approved" and shipper.state == "pending_approval" -> "Approve Shipper"
        state == "approved" -> "Reactivate Shipper"
        true -> "Disable Shipper"
      end

    socket =
      assign(
        socket,
        %{
          shipper_id: shipper_id,
          shipper_state: state,
          title: title
        }
      )

    socket = assign(socket, %{live_view: Elixir.FraytElixirWeb.AdminUpdateShipperState})

    {:noreply, assign(socket, :show_modal, true)}
  end

  def handle_event("save_edit", %{"shipper" => params}, socket) do
    live_view_action(__MODULE__, "save_edit", socket, fn ->
      shipper = Enum.find(socket.assigns.shippers, &(&1.id == socket.assigns.editable_id))

      case Accounts.update_shipper(shipper, params) do
        {:ok, _} ->
          {:noreply,
           socket
           |> update_results()
           |> assign(%{
             editable_id: nil,
             shipper_changeset: @empty_shipper_changeset
           })}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign(socket, :shipper_changeset, changeset)}
      end
    end)
  end

  def handle_info(:shippers_updated, socket) do
    live_view_action(__MODULE__, "shippers_updated", socket, fn ->
      {:noreply,
       socket
       |> update_results()
       |> assign(%{
         show_modal: false,
         shipper_id: nil,
         shipper_state: nil
       })}
    end)
  end

  def render(assigns) do
    FraytElixirWeb.Admin.ShippersView.render("index.html", assigns)
  end

  def list_records(socket, filters), do: {socket, Accounts.list_shippers(filters)}
end
