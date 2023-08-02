defmodule FraytElixirWeb.AdminSearchShipper do
  use Phoenix.LiveView
  import FraytElixirWeb.CreateUpdateCompany
  import FraytElixirWeb.SearchUsers

  def mount(_params, session, socket) do
    {:ok,
     assign(socket, %{
       fields: %{"email_1" => empty_email_field()},
       errors: [],
       company: Map.get(session, "chosen_company", nil),
       company_name: Map.get(session, "chosen_company_name", nil),
       location_id: Map.get(session, "chosen_location", nil),
       users_count: 1,
       attrs: Map.get(session, "attrs", nil)
     })}
  end

  def handle_event("close_modal", _event, socket) do
    send(socket.parent_pid, :close_modal)
    {:noreply, socket}
  end

  def handle_event("add_another_shipper", _event, socket) do
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

  def handle_event("remove_shipper" <> index, _event, socket) do
    {:noreply, remove_user(index, socket)}
  end

  def handle_event("override_" <> index, _event, socket) do
    {:noreply,
     assign(socket, %{
       fields:
         Map.put(socket.assigns.fields, "email_#{index}", %{
           socket.assigns.fields["email_#{index}"]
           | override: true
         }),
       errors: Keyword.delete(socket.assigns.errors, String.to_atom("email_#{index}"))
     })}
  end

  def handle_event(
        "change_shippers",
        %{"_target" => ["search_shipper", field], "search_shipper" => form},
        socket
      ) do
    {:noreply,
     assign(socket, %{
       fields:
         Map.put(socket.assigns.fields, field, %{
           email: form[field],
           override: false,
           user: nil,
           attrs: %{}
         }),
       errors: Keyword.delete(socket.assigns.errors, String.to_atom(field))
     })}
  end

  def handle_event("save_shippers", _event, socket) do
    socket = assign(socket, %{errors: []})

    socket = return_users_and_errors(socket)

    socket.assigns.errors
    |> Enum.count()
    |> case do
      0 ->
        save_shipper_changes(socket)
        send(socket.parent_pid, :new_shipper_added)
        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  def render(assigns) do
    FraytElixirWeb.Admin.CompaniesView.render("search_shipper.html", assigns)
  end
end
