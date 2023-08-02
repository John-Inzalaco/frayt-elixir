defmodule FraytElixirWeb.AdminSearchDriver do
  use Phoenix.LiveView
  import FraytElixirWeb.SearchUsers
  alias FraytElixir.Drivers.Driver
  alias FraytElixir.Accounts

  def mount(_params, session, socket) do
    schedule_id =
      case session["schedule"] do
        %{id: id} -> id
        _ -> nil
      end

    {:ok,
     assign(socket, %{
       fields: %{"email_1" => empty_email_field()},
       errors: [],
       users_count: 1,
       schedule_id: schedule_id,
       attrs: Map.get(session, "attrs", nil)
     })}
  end

  def handle_event("close_modal", _event, socket) do
    send(socket.parent_pid, :close_modal)
    {:noreply, socket}
  end

  def handle_event("add_another_driver", _event, socket) do
    {:noreply,
     assign(socket, %{
       users_count: socket.assigns.users_count + 1,
       fields:
         Map.put(
           socket.assigns.fields,
           "email_#{socket.assigns.users_count + 1}",
           empty_email_field()
         )
     })}
  end

  def handle_event(
        "change_drivers",
        %{"_target" => ["search_driver", field], "search_driver" => form},
        socket
      ) do
    {:noreply,
     assign(socket, %{
       fields:
         Map.put(socket.assigns.fields, field, %{
           email: form[field],
           override: false,
           shipper: nil,
           attrs: %{}
         }),
       errors: Keyword.delete(socket.assigns.errors, String.to_atom(field))
     })}
  end

  def handle_event("save_drivers", _event, socket) do
    socket =
      assign(socket, %{errors: []})
      |> return_users_and_errors(:driver)

    socket.assigns.errors
    |> Enum.count()
    |> case do
      0 ->
        add_drivers_to_schedule(socket)
        send(socket.parent_pid, :new_shipper_added)
        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  defp add_drivers_to_schedule(%{assigns: %{schedule_id: schedule_id, fields: fields}}),
    do:
      Enum.each(fields, fn {_key, %{user: user}} ->
        add_driver_to_schedule(schedule_id, user)
      end)

  defp add_driver_to_schedule(schedule_id, %Driver{id: driver_id}),
    do: Accounts.add_driver_to_schedule(%{schedule_id: schedule_id, driver_id: driver_id})

  defp add_driver_to_schedule(_schedule_id, _), do: nil

  def render(assigns) do
    FraytElixirWeb.Admin.CompaniesView.render("search_driver.html", assigns)
  end
end
