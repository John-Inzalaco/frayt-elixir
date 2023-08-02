defmodule FraytElixirWeb.AdminDriverNotificationLog do
  use Phoenix.LiveView
  alias FraytElixir.Drivers.Driver
  alias FraytElixir.Notifications.SentNotification
  alias FraytElixir.Repo
  import Ecto.Query, warn: false
  import Appsignal.Phoenix.LiveView, only: [live_view_action: 4]
  import FraytElixirWeb.DisplayFunctions

  def mount(_params, session, socket) do
    {:ok,
     assign(socket, %{
       notifications: get_driver_notifications(session["driver"]),
       time_zone: session["time_zone"],
       driver: session["driver"]
     })}
  end

  def handle_event("close_modal", _event, socket) do
    send(socket.parent_pid, :close_modal)
    {:noreply, socket}
  end

  def handle_event("go_to_match", %{"match_id" => match_id}, socket) do
    live_view_action(__MODULE__, "go_to_match", socket, fn ->
      {:noreply, redirect(socket, to: "/admin/matches/#{match_id}")}
    end)
  end

  def handle_event(
        "go_to_company",
        %{"company_id" => company_id, "location_id" => location_id},
        socket
      ) do
    live_view_action(__MODULE__, "go_to_company", socket, fn ->
      {:noreply, redirect(socket, to: "/admin/companies/#{company_id}/locations/#{location_id}")}
    end)
  end

  def get_notification_type(%SentNotification{
        match: match,
        delivery_batch: batch,
        schedule: schedule,
        admin_user: admin
      }) do
    cond do
      match != nil -> "Match"
      batch != nil -> "Batch"
      schedule != nil -> "Schedule"
      admin != nil -> "Admin (Custom)"
      true -> "Driver (Account)"
    end
  end

  def has_match(%SentNotification{match: nil}), do: false
  def has_match(%SentNotification{match: _match}), do: true

  def has_delivery_batch(%SentNotification{delivery_batch: nil}), do: false
  def has_delivery_batch(%SentNotification{delivery_batch: _delivery_batch}), do: true

  def has_schedule(%SentNotification{schedule: nil}), do: false
  def has_schedule(%SentNotification{schedule: _schedule}), do: true

  def has_admin(%SentNotification{admin_user: nil}), do: false
  def has_admin(%SentNotification{admin_user: _admin}), do: true

  def get_driver_notifications(%Driver{id: driver_id}) do
    days_ago_15 =
      DateTime.utc_now()
      |> DateTime.add(-15 * 24 * 60 * 60, :second)

    from(sn in SentNotification,
      where: sn.driver_id == ^driver_id and sn.inserted_at >= ^days_ago_15,
      order_by: [desc: sn.inserted_at],
      limit: 50
    )
    |> Repo.all()
    |> Repo.preload([
      :match,
      :admin_user,
      delivery_batch: [location: :company],
      schedule: [location: :company]
    ])
  end

  def render(assigns) do
    ~L"""
    <p class="caption">Limited to the last 50 notifications in the last 15 days</p>
    <table>
      <thead>
        <tr class="u-border--none">
          <th>Date Sent</th>
          <th>Type</th>
          <th>Target</th>
        </tr>
      </thead>
      <tbody>
        <%= for notification <- @notifications do %>
            <tr>
                <td>
                    <p><%= display_date_time(notification.inserted_at, @time_zone) %></p>
                </td>
                <td>
                  <p><%= get_notification_type(notification) %></p>
                </td>
                <td>
                  <%= cond do %>
                    <% has_match(notification) -> %>
                      <a onclick="" phx-keyup="go_to_match" phx-key="Enter" phx-click="go_to_match" phx-value-match_id="<%= notification.match.id %>">#<%= notification.match.shortcode %></a>
                    <% has_delivery_batch(notification) -> %>
                      <% location = notification.delivery_batch.location %>
                      <% company = location.company %>
                      <a onclick="" phx-keyup="go_to_company" phx-key="Enter" phx-click="go_to_company" phx-value-location_id="<%= location.id %>" phx-value-company_id="<%= company.id %>"> <%= company.name %></a>
                    <% has_schedule(notification) -> %>
                      <% location = notification.schedule.location %>
                      <% company = location.company %>
                      <a onclick="" phx-keyup="go_to_company" phx-key="Enter" phx-click="go_to_company"  phx-value-location_id="<%= location.id %>" phx-value-company_id="<%= company.id %>"><%= company.name %></a>
                    <% has_admin(notification) -> %>
                      <%= notification.admin_user.name %>
                    <% true -> %>
                      Self
                  <% end %>
                </td>
                <td></td>
            </tr>
        <% end %>
      </tbody>
    </table>
    """
  end
end
