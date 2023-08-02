defmodule FraytElixirWeb.LiveComponent.FormRepeater do
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form
  import FraytElixirWeb.Helpers.FormList

  def handle_event("form_repeater.add", _params, socket) do
    send_repeater_update(socket, &add_item/4, socket.assigns.default)

    {:noreply, socket}
  end

  def handle_event("form_repeater.remove", %{"index" => index}, socket) do
    index = if is_binary(index), do: String.to_integer(index), else: index

    send_repeater_update(socket, &remove_item/4, index)

    {:noreply, socket}
  end

  def handle_event("form_repeater.swap", %{"swap" => [index1, index2]}, socket) do
    send_repeater_update(socket, &swap_items/4, {index1, index2})

    {:noreply, socket}
  end

  def render(assigns) do
    ~L"""
      <ul class="form-repeater <%= @class %>" id="<%= @id %>" <%= if @draggable, do: "phx-hook=DragDropRepeater" %>>
        <%= for i <- inputs_for(@form, @field) do %>
          <li class="form-repeater__item <%= @item_class %>" id="<%= @id %>_item_<%= i.index %>" data-index="<%= i.index %>">
            <fieldset <%= if @draggable, do: "draggable=true" %>>
              <%= hidden_inputs_for(i) %>
              <%= @renderer.(i) %>
            </fieldset>
          </li>
        <% end %>
      </ul>
    """
  end

  def send_repeater_update(socket, callback, args) do
    send(
      socket.root_pid,
      {:update_changeset, callback,
       [
         socket.assigns.form,
         socket.assigns.field,
         args
       ]}
    )
  end
end
