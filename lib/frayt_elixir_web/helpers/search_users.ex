defmodule FraytElixirWeb.SearchUsers do
  import Phoenix.LiveView
  alias FraytElixir.Accounts.Shipper
  alias FraytElixir.Drivers.Driver
  alias FraytElixir.Accounts
  alias FraytElixir.Repo

  def empty_email_field, do: %{email: nil, override: false, user: nil, attrs: %{}}

  def return_users_and_errors(socket, type \\ :shipper) do
    Enum.reduce(socket.assigns.fields, socket, fn email, socket ->
      %{user: %{email: elem(email, 1).email}}
      |> search_users_unless_overridden(socket, email, type)
    end)
  end

  def search_users_unless_overridden(_, socket, {_, %{override: true}}, _), do: socket

  def search_users_unless_overridden(new_user_attrs, socket, email, type),
    do: search_users(socket, email, new_user_attrs, type)

  def search_users(socket, {"email_" <> index, %{email: email}}, _attrs, _)
      when email in ["", nil],
      do: remove_user(index, socket)

  def search_users(socket, info, attrs, :driver), do: search_drivers(socket, info, attrs)
  def search_users(socket, info, attrs, :shipper), do: search_shippers(socket, info, attrs)

  def search_shippers(socket, {key, %{email: email}} = email_fields, attrs) do
    case Accounts.get_shipper_by_email(email) do
      %Shipper{} = shipper ->
        shipper = Repo.preload(shipper, :user)
        add_user_to_fields(socket, attrs, shipper, email_fields)

      nil ->
        add_not_found_error(socket, key, "Shipper")
    end
  end

  def search_drivers(socket, {key, %{email: email}} = email_fields, attrs) do
    query = Driver.get_driver_by_email(Driver, email)

    case FraytElixir.Repo.one(query) do
      %Driver{} = driver -> add_user_to_fields(socket, attrs, driver, email_fields)
      nil -> add_not_found_error(socket, key, "Driver")
    end
  end

  def add_user_to_fields(
        socket,
        new_user_attrs,
        %Shipper{location_id: location_id} = shipper,
        {key, _} = email
      )
      when not is_nil(location_id),
      do:
        assign(socket, %{
          fields: found_user_fields(email, socket, shipper, new_user_attrs, false),
          errors:
            Keyword.put(
              socket.assigns.errors,
              String.to_atom(key),
              {"Shipper is already assigned to a location."}
            )
        })

  def add_user_to_fields(socket, new_user_attrs, user, email),
    do: assign(socket, %{fields: found_user_fields(email, socket, user, new_user_attrs, true)})

  def found_user_fields({key, %{email: email}}, socket, user, new_user_attrs, override) do
    new_user_attrs = Map.put(new_user_attrs, :user, %{email: email, id: user.id})

    Map.put(socket.assigns.fields, key, %{
      email: email,
      override: override,
      user: user,
      attrs: new_user_attrs
    })
  end

  def remove_user(index, socket) do
    assign(socket, %{
      fields:
        Enum.reduce(socket.assigns.fields, %{}, fn {"email_" <> i, value}, acc ->
          String.to_integer(i)
          |> reduce_email_fields(index, value, acc)
        end),
      users_count: subtract_from_users_count(socket.assigns.users_count)
    })
  end

  def reduce_email_fields(i, index, value, acc) when i < index,
    do: Map.put(acc, "email_#{i}", value)

  def reduce_email_fields(i, index, _value, acc) when i == index and index == 1,
    do: Map.put(acc, "email_#{i}", empty_email_field())

  def reduce_email_fields(i, index, _value, acc) when i == index, do: acc

  def reduce_email_fields(i, index, value, acc) when i > index,
    do: Map.put(acc, "email_#{i - 1}", value)

  def subtract_from_users_count(1), do: 1
  def subtract_from_users_count(count), do: count - 1

  defp add_not_found_error(socket, key, type),
    do:
      assign(socket, %{
        errors:
          Keyword.put(
            socket.assigns.errors,
            String.to_atom(key),
            {"#{type} does not exist"}
          )
      })
end
