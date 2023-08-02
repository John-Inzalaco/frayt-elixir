defmodule FraytElixirWeb.UploadDriverPhotos do
  use Phoenix.LiveView
  import Phoenix.HTML.Form
  import FraytElixirWeb.DisplayFunctions

  def mount(
        _params,
        %{
          "driver" => driver,
          "title" => title
        },
        socket
      ) do
    descriptor =
      case title do
        "Upload Profile Photo" -> "profile"
        "Upload Driver's License Photo" -> "license"
      end

    {:ok,
     assign(socket,
       driver: driver,
       title: title,
       descriptor: descriptor
     )}
  end

  def handle_event("close_modal", _event, socket) do
    send(socket.parent_pid, :close_modal)
    {:noreply, socket}
  end

  def render(assigns) do
    ~L"""
    <%= f = form_for :driver_photos, "/admin/drivers/#{@driver.id}/photos", [multipart: true] %>
      <%= inputs_for f, @descriptor, fn i -> %>
        <div class="u-push__top--sm">
          <%= label i, :document, title_case(@descriptor) %>
          <%= file_input i, :document %>
        </div>

        <%= if @descriptor in ["license"] do %>
          <div class="u-push__top--sm">
            <%= label i, :expires_at, "Expires At" %>
            <%= date_input i, :expires_at %>
          </div>
        <% end %>

        <div class="u-pad__top u-text--center width--full">
          <div class="u-pad__bottom--sm caption">Note: Uploading a photo will replace the existing photo.</div>
          <div>
            <button class="button button--primary">Save</button>
            <a class="button" tabindex=0 phx-keyup="close_modal" phx-key="Enter" phx-click="close_modal" onclick="">Cancel</a>
          </div>
        </div>
      <% end %>
    </form>
    """
  end
end
