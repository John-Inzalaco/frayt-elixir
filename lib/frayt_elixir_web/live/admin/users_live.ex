defmodule FraytElixirWeb.Admin.UsersLive do
  use Phoenix.LiveView

  use FraytElixirWeb.DataTable,
    base_url: "/admin/settings/users",
    default_filters: %{order_by: :name, order: :asc, per_page: 12},
    filters: [
      %{key: :query, type: :string, default: nil},
      %{key: :role, type: :atom, default: nil},
      %{key: :show_disabled, type: :boolean, default: false}
    ],
    model: :users,
    handle_params: :root

  alias FraytElixir.Accounts
  alias FraytElixir.Accounts.AdminUser
  alias FraytElixir.Accounts.User
  alias FraytElixir.Convert
  alias FraytElixir.Helpers.NumberConversion

  import FraytElixir.AtomizeKeys
  import FraytElixir.Guards

  def invite_changeset(attrs \\ %{}),
    do: AdminUser.user_changeset(%AdminUser{user: %User{}}, attrs)

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket, %{
       invite: invite_changeset(),
       admin_changeset: nil,
       editing_admin: nil
     })}
  end

  def handle_event("cancel_edit", _event, socket) do
    {:noreply, assign(socket, %{editing_admin: nil, admin_changeset: nil})}
  end

  def handle_event("edit_admin", %{"admin_id" => admin_id}, socket) do
    admin = Enum.find(socket.assigns.users, &(&1.id == admin_id))

    {:noreply,
     assign(socket, %{
       editing_admin: admin,
       admin_changeset: AdminUser.user_changeset(admin, %{})
     })}
  end

  def handle_event("change_admin", %{"admin_user" => edit_form}, socket) do
    attrs = convert_admin_attrs(edit_form)

    changeset =
      socket.assigns.editing_admin |> AdminUser.user_changeset(attrs) |> Map.put(:action, :insert)

    {:noreply, assign(socket, :admin_changeset, changeset)}
  end

  def handle_event("save_admin", %{"admin_user" => edit_form}, socket) do
    attrs = convert_admin_attrs(edit_form)
    admin = socket.assigns.editing_admin

    case Accounts.update_admin(admin, attrs) do
      {:ok, _admin} ->
        {:noreply,
         socket
         |> update_results()
         |> assign(%{editing_admin: nil, admin_changeset: nil})}

      {:error, changeset} ->
        {:noreply, assign(socket, :admin_changeset, changeset)}
    end
  end

  def handle_event("invite_admin", %{"admin_user" => attrs}, socket) do
    attrs = atomize_keys(attrs)

    case Accounts.invite_admin(attrs) do
      {:ok, _admin_user} ->
        changeset = invite_changeset()

        {:noreply,
         socket
         |> update_results()
         |> assign(:invite, changeset)}

      {:error, changeset} ->
        {:noreply, assign(socket, :invite, changeset)}
    end
  end

  def handle_event("change_invites", %{"admin_user" => attrs}, socket) do
    changeset =
      attrs
      |> atomize_keys()
      |> invite_changeset()
      |> Map.put(:action, :insert)

    {:noreply, assign(socket, %{invite: changeset})}
  end

  def handle_event("cancel_invite", _event, socket) do
    {:noreply, assign(socket, %{invite: invite_changeset()})}
  end

  def handle_info({:delivered_email, _}, socket) do
    {:noreply, socket}
  end

  def render(assigns) do
    FraytElixirWeb.Admin.SettingsView.render("users.html", assigns)
  end

  def list_records(socket, filters) do
    {socket, Accounts.list_admins(filters)}
  end

  defp convert_admin_attrs(attrs) do
    attrs = atomize_keys(attrs)

    case Map.get(attrs, :sales_goal) do
      goal when is_empty(goal) ->
        attrs

      goal ->
        sales_goal = NumberConversion.dollars_to_cents(goal)
        %{attrs | :sales_goal => sales_goal}
    end
  end
end
