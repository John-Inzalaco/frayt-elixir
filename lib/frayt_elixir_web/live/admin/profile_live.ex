defmodule FraytElixirWeb.Admin.ProfileLive do
  use Phoenix.LiveView
  alias FraytElixir.Accounts
  alias FraytElixir.Accounts.AdminUser
  import FraytElixir.AtomizeKeys

  @default_inputs %{
    "old_password" => nil,
    "new_password" => nil,
    "confirm_password" => nil
  }

  def mount(
        _params,
        %{"current_user" => current_user, "reset_password" => reset_password},
        socket
      ) do
    socket =
      if reset_password,
        do:
          put_flash(
            socket,
            :error,
            "Please reset your password. The reset link and code you were emailed will not work again."
          ),
        else: socket

    {:ok,
     assign(socket, %{
       user: current_user.admin,
       reset_password: reset_password,
       password_inputs: @default_inputs,
       password_view: :password,
       is_editing: false,
       admin_changeset: AdminUser.user_changeset(current_user.admin, %{}),
       errors: []
     })}
  end

  def handle_event("toggle_editing", _event, socket) do
    {:noreply,
     assign(socket, %{
       is_editing: !socket.assigns.is_editing,
       admin_changeset: AdminUser.user_changeset(socket.assigns.user, %{})
     })}
  end

  def handle_event("change_admin", %{"admin_user" => edit_form}, socket) do
    attrs = atomize_keys(edit_form)

    changeset =
      socket.assigns.user |> AdminUser.user_changeset(attrs) |> Map.put(:action, :insert)

    {:noreply, assign(socket, :admin_changeset, changeset)}
  end

  def handle_event("save_admin", %{"admin_user" => edit_form}, socket) do
    attrs = atomize_keys(edit_form)
    admin = socket.assigns.user

    case Accounts.update_admin(admin, attrs) do
      {:ok, admin} ->
        {:noreply,
         assign(socket, %{
           is_editing: false,
           user: admin,
           admin_changeset: AdminUser.user_changeset(admin, %{})
         })}

      {:error, changeset} ->
        {:noreply, assign(socket, :admin_changeset, changeset)}
    end
  end

  def handle_event("toggle_password_view", _event, socket) do
    {:noreply,
     assign(
       socket,
       :password_view,
       if socket.assigns.password_view == :password do
         :text
       else
         :password
       end
     )}
  end

  def handle_event("change_password_inputs", %{"password_form" => form}, socket) do
    {:noreply, assign(socket, %{password_inputs: form})}
  end

  def handle_event("clear_flash", _event, socket) do
    {:noreply, clear_flash(socket)}
  end

  def handle_event(
        "reset_password",
        %{
          "password_form" => %{
            "old_password" => old_password,
            "confirm_password" => confirm_password,
            "new_password" => new_password
          }
        },
        socket
      ) do
    socket = clear_flash(socket)
    admin = socket.assigns.user
    {fails_filled, socket} = filled_in?(old_password, new_password, socket)
    {fails_confirm, socket} = matching_confirm?(new_password, confirm_password, socket)

    {message, changeset} =
      if fails_confirm or fails_filled do
        {:other_error, nil}
      else
        params = %{new_password: new_password, old_password: old_password}

        Accounts.get_admin(admin.id)
        |> Accounts.update_admin_password(params)
      end

    socket =
      case message do
        :other_error ->
          socket

        :ok ->
          assign(socket, %{password_inputs: @default_inputs})
          |> put_flash(:success, "Password changed")

        :error ->
          case changeset do
            :invalid_credentials ->
              put_flash(socket, :error, "Invalid old password")

            _ ->
              Enum.filter(changeset.errors, &(elem(&1, 0) == :password))
              |> Enum.map(&(elem(&1, 1) |> elem(0)))
              |> Enum.reduce(
                socket,
                &put_flash(&2, :error, Map.get(&2.assigns.flash, "error", []) ++ [&1])
              )
          end
      end

    {:noreply, socket}
  end

  def matching_confirm?(new_password, confirm_password, socket) do
    case new_password do
      ^confirm_password ->
        {false, socket}

      _ ->
        {true,
         put_flash(
           socket,
           :error,
           Map.get(socket.assigns.flash, "error", []) ++ ["Passwords must match"]
         )}
    end
  end

  def handle_event({:sent_email, _}, socket) do
    {:noreply, socket}
  end

  def filled_in?(old_password, new_password, socket) do
    msgs =
      if String.trim(new_password) == "" do
        ["Please enter a new password"]
      else
        []
      end

    msgs =
      if String.trim(old_password) == "" do
        ["Please enter the old password" | msgs]
      else
        msgs
      end

    if msgs != [],
      do:
        {true,
         put_flash(
           socket,
           :error,
           Map.get(socket.assigns.flash, "error", []) ++ msgs
         )},
      else: {false, socket}
  end

  def render(assigns) do
    FraytElixirWeb.Admin.SettingsView.render("profile.html", assigns)
  end
end
