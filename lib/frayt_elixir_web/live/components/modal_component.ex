defmodule FraytElixirWeb.LiveComponent.ModalLive do
  use Phoenix.LiveComponent

  def stringify_keys(map) do
    Enum.reduce(map, %{}, fn {k, v}, acc -> Map.put(acc, to_string(k), v) end)
  end

  def render(assigns) do
    ~L"""
    <div class="modal">
      <div class="modal__wrapper <%= if @wide === "true", do: 'modal__wrapper--wide' %>">
        <div class="modal__header">
          <h3><%= @title %></h3>
          <div>
            <a onclick="" tabindex=0 phx-keyup="close_modal" phx-key="Enter" phx-click="close_modal"><i class="material-icons icon u-pointer">cancel</i></a>
          </div>
        </div>
        <div class="modal__content">
          <%= live_render @socket, @live_view, id: @child_id, session: stringify_keys(assigns) %>
        </div>
      </div>
    </div>
    """
  end
end
