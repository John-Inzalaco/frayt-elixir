defmodule FraytElixirWeb.UploadVehiclePhotos do
  use Phoenix.LiveView
  import Phoenix.HTML.Form
  import FraytElixirWeb.DisplayFunctions

  def mount(
        _params,
        %{
          "driver" => driver,
          "title" => "Upload Registration Photo" = title,
          "vehicle_id" => vehicle_id
        },
        socket
      ) do
    {:ok,
     assign(socket,
       driver_id: driver.id,
       title: title,
       photo_descriptors: ["registration"],
       vehicle_id: vehicle_id
     )}
  end

  def mount(
        _params,
        %{
          "driver" => driver,
          "title" => "Upload Insurance Photo" = title,
          "vehicle_id" => vehicle_id
        },
        socket
      ) do
    {:ok,
     assign(socket,
       driver_id: driver.id,
       title: title,
       photo_descriptors: ["insurance"],
       vehicle_id: vehicle_id
     )}
  end

  def mount(
        _params,
        %{
          "driver" => driver,
          "title" => "Upload Vehicle Photos" = title,
          "vehicle_id" => vehicle_id
        },
        socket
      ) do
    {:ok,
     assign(socket,
       driver_id: driver.id,
       title: title,
       photo_descriptors: [
         "passengers_side",
         "drivers_side",
         "cargo_area",
         "front",
         "back",
         "vehicle_type"
       ],
       vehicle_id: vehicle_id
     )}
  end

  def mount(
        _params,
        %{
          "driver" => driver,
          "title" => "Upload Carrier Agreement" = title,
          "vehicle_id" => vehicle_id
        },
        socket
      ) do
    {:ok,
     assign(socket,
       driver_id: driver.id,
       title: title,
       photo_descriptors: ["carrier_agreement"],
       vehicle_id: vehicle_id
     )}
  end

  def handle_event("close_modal", _event, socket) do
    send(socket.parent_pid, :close_modal)
    {:noreply, socket}
  end

  def render(assigns) do
    ~L"""
    <%= f = form_for :vehicle_photos, "/admin/drivers/#{@driver_id}/vehicles/#{@vehicle_id}/photos", [multipart: true] %>
      <%= for descriptor <- @photo_descriptors do %>
        <%= inputs_for f, descriptor, fn i -> %>
          <div class="u-push__top--sm">
            <%= label i, :document, title_case(descriptor) %>
            <%= file_input i, :document %>
          </div>

          <%= if descriptor in ["insurance", "registration"] do %>
            <div class="u-push__top--sm">
              <%= label i, :expires_at, "Expires At" %>
              <%= date_input i, :expires_at %>
            </div>
          <% end %>
        <% end %>
      <% end %>

      <div class="u-pad__top u-text--center width--full">
        <div class="u-pad__bottom--sm caption">Note: Uploading a photo will replace the existing photo.</div>
        <div>
          <button class="button button--primary">Save</button>
          <a class="button" tabindex=0 phx-keyup="close_modal" phx-key="Enter" phx-click="close_modal" onclick="">Cancel</a>
        </div>
        </div>
    </form>
    """
  end
end
