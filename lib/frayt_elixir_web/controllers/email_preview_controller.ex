defmodule FraytElixirWeb.PreviewEmailController do
  use FraytElixirWeb, :controller
  alias FraytElixir.Notifications.MatchNotifications
  import FraytElixir.Factory

  def show(conn, %{"type" => "match_status"} = attrs) do
    match =
      insert(:completed_match,
        match_stops: build_match_stops_with_items([:delivered, :delivered, :undeliverable]),
        pickup_notes: "Pickup at the back door"
      )

    mst =
      insert(:match_state_transition,
        from: :picked_up,
        to: :completed
      )

    email = MatchNotifications.send_match_status_email(match, mst)

    render_email(conn, email, Map.get(attrs, "content_type", "html"))
  end

  def show(conn, %{"type" => "match_created"} = attrs) do
    match = insert(:scheduled_match)
    mst = insert(:match_state_transition, from: :pending, to: :scheduled)
    email = MatchNotifications.send_match_status_email(match, mst)
    render_email(conn, email, Map.get(attrs, "content_type", "html"))
  end

  def show(conn, %{"type" => "shipper_invite"} = attrs) do
    email =
      FraytElixir.Email.shipper_invite_email(%{
        email: "john@smith.com",
        password_reset_code: "ABCDEFGH",
        first_name: "john",
        last_name: "smith"
      })

    render_email(conn, email, Map.get(attrs, "content_type", "html"))
  end

  defp render_email(conn, email, "html") do
    conn
    |> Plug.Conn.put_resp_content_type("text/html")
    |> send_resp(:ok, email.html_body)
  end

  defp render_email(conn, email, _) do
    conn
    |> Plug.Conn.put_resp_content_type("text/plain")
    |> send_resp(:ok, email.text_body)
  end
end
