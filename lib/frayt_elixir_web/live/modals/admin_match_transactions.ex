defmodule FraytElixirWeb.AdminMatchTransactions do
  use Phoenix.LiveView
  alias FraytElixir.Payments
  alias FraytElixir.Shipment.Match
  alias FraytElixir.Repo
  alias FraytElixirWeb.DataTable

  def mount(_params, %{"match" => %Match{} = match} = session, socket) do
    {:ok,
     assign(socket, %{
       match: match,
       payments: Payments.list_charges(match.id),
       show_more: nil,
       time_zone: session["time_zone"]
     })}
  end

  def mount(_params, %{"match" => match_id} = session, socket) do
    %Match{payment_transactions: payments} =
      match = Repo.get!(Match, match_id) |> Repo.preload(payment_transactions: :driver)

    {:ok,
     assign(socket, %{
       match: match,
       payments: payments,
       show_more: nil,
       time_zone: session["time_zone"]
     })}
  end

  def handle_event("close_modal", _event, socket) do
    send(socket.parent_pid, :close_modal)
    {:noreply, socket}
  end

  def handle_event("toggle_show_more", %{"paymentid" => payment_id}, socket) do
    {:noreply,
     assign(socket, :show_more, DataTable.toggle_show_more(socket.assigns.show_more, payment_id))}
  end

  def render(assigns) do
    ~L"""
    <section>
      <div class="width--full u-push__bottom">
        <%= if length(@payments) < 1 do %>
          <p>There are no payment transactions for this match yet.</p>
        <% else %>
          <%= Phoenix.View.render(FraytElixirWeb.Admin.PaymentsView, "_match_payment_history.html", time_zone: @time_zone, payments: @payments, match: @match, show_more: @show_more) %>
        <% end %>
      </div>
    </section>
    """
  end
end
