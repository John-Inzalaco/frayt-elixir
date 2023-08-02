defmodule FraytElixirWeb.AdminDriverReviews do
  use Phoenix.LiveView
  alias FraytElixir.Drivers
  import Appsignal.Phoenix.LiveView, only: [live_view_action: 4]
  import FraytElixirWeb.DisplayFunctions, only: [range_from_one_to: 1]

  @base_url "/admin/matches"

  def mount(
        _params,
        %{
          "driver" => %{id: driver_id} = driver
        },
        socket
      ) do
    with %{
           completed_matches: total_completed_matches,
           rated_matches: total_rated_matches
         } <- Drivers.get_driver_metrics(driver),
         poorly_rated_matches <- Drivers.get_poorly_rated_matches(driver_id) do
      {:ok,
       assign(socket,
         total_completed_matches: total_completed_matches,
         total_rated_matches: total_rated_matches,
         poorly_rated_matches: poorly_rated_matches
       )}
    else
      {:error, _} ->
        {:error, "I died"}

      _ ->
        {:error, "I died"}
    end
  end

  def handle_event("close_modal", _event, socket) do
    send(socket.parent_pid, :close_modal)
    {:noreply, socket}
  end

  def handle_event("go_to_match", %{"match_id" => match_id}, socket) do
    live_view_action(__MODULE__, "go_to_match", socket, fn ->
      {:noreply, redirect(socket, to: "#{@base_url}/#{match_id}")}
    end)
  end

  def render(assigns) do
    ~L"""
    <table>
      <thead>
        <tr class="u-border--none">
          <th>Rating</th>
          <th>Reason</th>
          <th>Match</th>
        </tr>
      </thead>
      <tbody>
        <%= for %{match_id: id, match_shortcode: shortcode, rating: rating, reason: reason} <- @poorly_rated_matches do %>
          <tr>
            <td>
              <div class="label__stars">
                <%= for _ <- range_from_one_to(round(rating)) do %>
                  <i data-test-id="star" class="material-icons icon u-light-gray u-align__vertical--middle">star</i>
                <% end %>
                <%= for _ <- range_from_one_to(5 - round(rating)) do %>
                  <i data-test-id="empty" class="material-icons icon u-light-gray u-align__vertical--middle">star_outline</i>
                <% end %>
              </div>
            </td>
            <td><%= reason %></td>
            <td>
              <a onclick="" phx-keyup="go_to_match" phx-key="Enter" phx-click="go_to_match" phx-value-match_id="<%= id %>"><%= shortcode %></a>
            </td>
          </tr>
        <% end %>
      </tbody>
    </table>
    """
  end
end
