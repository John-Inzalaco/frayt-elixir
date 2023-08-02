defmodule FraytElixirWeb.AdminAddCancelCharge do
  use Phoenix.LiveView
  alias FraytElixir.Convert
  alias FraytElixir.Matches
  alias FraytElixir.Contracts

  import FraytElixirWeb.DisplayFunctions,
    only: [handle_empty_string: 2, humanize_update_errors: 2]

  def mount(_params, session, socket) do
    match = session["match"]
    rule = Contracts.get_match_cancellation_pay_rule(match)

    charge_assigns =
      case rule do
        %{cancellation_percent: cancellation_percent, driver_percent: driver_percent} ->
          [
            cancel_charge: cancellation_percent * 100,
            cancel_charge_driver_pay: driver_percent * 100
          ]

        _ ->
          [
            cancel_charge: 50,
            cancel_charge_driver_pay: round(match.driver_cut * 100)
          ]
      end

    {:ok,
     socket
     |> assign(charge_assigns)
     |> assign(match: session["match"], rule: rule)}
  end

  def handle_event("close_modal", _event, socket) do
    send(socket.parent_pid, :close_modal)
    {:noreply, socket}
  end

  def handle_event(
        "add_charge",
        %{
          "add_charge_form" => %{
            "cancel_charge" => cancel_charge,
            "cancel_charge_driver_pay" => cancel_charge_driver_pay
          }
        },
        socket
      ) do
    attrs = %{
      cancellation_percent: Convert.to_integer(cancel_charge, 0) / 100,
      driver_percent: Convert.to_integer(cancel_charge_driver_pay, 0) / 100
    }

    case Matches.apply_cancel_charge(socket.assigns.match, attrs) do
      {:ok, match} ->
        send(socket.parent_pid, {:updated_match, match})

      error ->
        send(
          socket.parent_pid,
          {:send_alert, :danger, humanize_update_errors(error, "Cancel Charge")}
        )
    end

    {:noreply, socket}
  end

  def handle_event(
        "update_charge",
        %{
          "add_charge_form" => %{
            "cancel_charge" => cancel_charge,
            "cancel_charge_driver_pay" => cancel_charge_driver_pay
          }
        },
        socket
      ) do
    {:noreply,
     assign(socket, %{
       cancel_charge: handle_empty_string(cancel_charge, "0") |> Integer.parse() |> elem(0),
       cancel_charge_driver_pay:
         handle_empty_string(cancel_charge_driver_pay, "0") |> Integer.parse() |> elem(0)
     })}
  end

  def render(assigns) do
    ~L"""
      <section>
        <form phx-submit="add_charge" phx-change="update_charge" class="width--full">
          <div>
          <%= Phoenix.View.render FraytElixirWeb.Admin.MatchesView, "_add_cancel_charge.html", form_name: :add_charge_form, rule: @rule, cancel_charge: @cancel_charge, cancel_charge_driver_pay: @cancel_charge_driver_pay, amount_charged: @match.amount_charged, has_driver?: not is_nil(@match.driver) %>
          </div>
          <div class="u-pad__top u-text--center width--full">
            <button class="button button--primary">Add Cancel Charge</button>
            <a class="button" onclick="" phx-keyup="close_modal" phx-key="Enter" tabindex=0 phx-click="close_modal">Cancel</a>
          </div>
        </form>
      </section>
    """
  end
end
