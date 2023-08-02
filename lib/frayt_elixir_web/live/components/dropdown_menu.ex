defmodule FraytElixirWeb.LiveComponent.DropdownMenu do
  use Phoenix.LiveComponent
  # import Phoenix.HTML.Tag

  def mount(socket) do
    {:ok, assign(socket, :open?, false)}
  end

  def handle_event("toggle_dropdown", _params, socket) do
    {:noreply, assign(socket, :open?, !socket.assigns.open?)}
  end

  def render(assigns) do
    ~L"""
      <% open_class = if @open?, do: "drop-down--open" %>
      <div class="drop-down <%= open_class %> <%= @class %>" id="<%= @id %>" phx-click="toggle_dropdown" phx-target="<%= @myself %>">
        <div class="drop-down__label"><%= @renderer.() %></div>

        <div class="drop-down__menu">
          <%= if @header do %>
            <span class="drop-down__menu-item-header"><%= @header %></span>
          <% end %>
          <%= for item <- @items do %>
            <%= if @item_renderer do %>
              <%= @item_renderer.(item) %>
            <% else %>
              <% {label, state, stop} = item %>
              <a onclick="" class="drop-down__menu-item" phx-click="mark_stop_as:<%= state %>" phx-value-stop-id="<%= stop.id %>"><%= label %></a>
            <% end %>
          <% end %>
        </div>
      </div>
    """
  end
end
