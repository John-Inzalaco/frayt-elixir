defmodule FraytElixirWeb.ViewDriverPhoto do
  use Phoenix.LiveView

  import FraytElixirWeb.DisplayFunctions
  import FraytElixir.Guards

  def mount(_params, session, socket) do
    %{"images" => image_types, "title" => title, "driver" => driver} = session

    parent =
      case session do
        %{"vehicle_id" => vehicle_id} when not is_empty(vehicle_id) ->
          Enum.find(driver.vehicles, &(&1.id == vehicle_id))

        _ ->
          driver
      end

    image_types = String.split(image_types, ",")

    images =
      parent.images
      |> Enum.filter(fn i ->
        Atom.to_string(i.type) in image_types
      end)

    {:ok,
     assign(socket,
       title: title,
       images: images
     )}
  end

  def render(assigns) do
    ~L"""
    <%= for image <- @images do %>
      <div>
        <h5><%= title_case(image.type) %></h5>
        <%= if image.expires_at do %>
          <p class="caption">
            Expires at <%= display_date(image.expires_at) %>
          </p>
        <% end %>
        <img src="<%= get_image_url(image) %>" alt="<%= title_case(image.type) %>" class="u-pad__top--xs u-pad__bottom--md" />
      </div>
    <% end %>
    """
  end

  defp get_image_url(%{vehicle_id: id, document: document}), do: get_photo_url(id, document)
  defp get_image_url(%{driver_id: id, document: document}), do: get_photo_url(id, document)
end
