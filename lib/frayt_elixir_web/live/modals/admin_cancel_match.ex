defmodule FraytElixirWeb.AdminCancelMatch do
  use Phoenix.LiveView
  alias FraytElixir.Shipment
  alias FraytElixir.Shipment.Match
  import Phoenix.HTML.Form
  alias FraytElixir.Convert
  alias FraytElixir.Contracts

  import FraytElixirWeb.DisplayFunctions,
    only: [handle_empty_string: 1, handle_empty_string: 2, humanize_update_errors: 2]

  def mount(_params, session, socket) do
    match = session["match"]
    rule = Contracts.get_match_cancellation_pay_rule(match)

    cancellation_code = match.contract && List.first(match.contract.cancellation_codes)

    charge_assigns =
      case rule do
        %{cancellation_percent: cancellation_percent, driver_percent: driver_percent} ->
          [
            cancel_charge: cancellation_percent * 100,
            cancel_charge_driver_pay: driver_percent * 100,
            add_cancel_charge: true
          ]

        _ ->
          [
            cancel_charge: 50,
            cancel_charge_driver_pay: round(match.driver_cut * 100),
            add_cancel_charge: false
          ]
      end

    {:ok,
     socket
     |> assign(charge_assigns)
     |> assign(
       match: session["match"],
       rule: rule,
       cancellation_reason: cancellation_code && cancellation_code.message,
       code: cancellation_code && cancellation_code.code
     )}
  end

  def handle_event("close_modal", _event, socket) do
    send(socket.parent_pid, :close_modal)
    {:noreply, socket}
  end

  def handle_event(
        "cancel_match",
        %{
          "cancel_form" => %{
            "code" => code,
            "cancel_reason" => reason,
            "add_cancel_charge" => add_cancel_charge,
            "cancel_charge" => cancel_charge,
            "cancel_charge_driver_pay" => cancel_charge_driver_pay
          }
        },
        socket
      ) do
    charge_attrs =
      case add_cancel_charge do
        "true" ->
          %{
            cancellation_percent: Convert.to_integer(cancel_charge, 0) / 100,
            driver_percent: Convert.to_integer(cancel_charge_driver_pay, 0) / 100
          }

        _ ->
          %{
            cancellation_percent: 0.0,
            driver_percent: 0.0
          }
      end

    case Shipment.admin_cancel_match(
           socket.assigns.match,
           handle_empty_string(reason),
           code,
           charge_attrs
         ) do
      {:ok, %Match{state: :admin_canceled} = match} ->
        send(socket.parent_pid, {:match_canceled, match})

      error ->
        send(
          socket.parent_pid,
          {:send_alert, :danger, humanize_update_errors(error, "Match")}
        )
    end

    {:noreply, socket}
  end

  def handle_event(
        "update_charge",
        %{
          "_target" => ["cancel_form", field],
          "cancel_form" => %{
            "cancel_charge" => cancel_charge,
            "add_cancel_charge" => add_cancel_charge,
            "cancel_charge_driver_pay" => cancel_charge_driver_pay
          }
        },
        socket
      )
      when field in ["add_cancel_charge", "cancel_charge", "cancel_charge_driver_pay"] do
    {:noreply,
     assign(socket, %{
       cancel_charge: handle_empty_string(cancel_charge, "0") |> Integer.parse() |> elem(0),
       add_cancel_charge: add_cancel_charge == "true",
       cancel_charge_driver_pay:
         handle_empty_string(cancel_charge_driver_pay, "0") |> Integer.parse() |> elem(0)
     })}
  end

  def handle_event(
        "update_charge",
        %{
          "_target" => ["cancel_form", "code"],
          "cancel_form" => %{"code" => code}
        },
        socket
      ) do
    cancel_reason =
      socket.assigns.match.contract.cancellation_codes
      |> Enum.find(%{}, &(&1.code == code))
      |> Map.get(:message)

    {:noreply,
     assign(socket, %{
       cancellation_reason: cancel_reason,
       code: code
     })}
  end

  def handle_event(
        "update_charge",
        %{
          "_target" => ["cancel_form", "cancel_reason"],
          "cancel_form" => %{"cancel_reason" => cancel_reason}
        },
        socket
      ) do
    {:noreply, assign(socket, %{cancellation_reason: cancel_reason})}
  end

  def render(assigns) do
    ~L"""
      <section>
        <div class="width--full">
        <p class="u-push__bottom--xs">Are you sure you want to cancel this match?</p>
        </div>
        <form phx-submit="cancel_match" phx-change="update_charge" class="width--full">
          <div>
            <%= if @match.driver_id do %>
              <div class="slider--vertical">
                <%= label :cancel_form, :add_cancel_charge, "Add Cancel Charge" %>
                <div class="slide">
                  <%= checkbox :cancel_form, :add_cancel_charge, checked: @add_cancel_charge  %>
                  <label class="caption" for="cancel_form_add_cancel_charge"></label>
                </div>
              </div>
            <% else %>
              <%= hidden_input :cancel_form, :add_cancel_charge, value: false %>
            <% end %>
            <%= if @add_cancel_charge do %>
              <%= Phoenix.View.render FraytElixirWeb.Admin.MatchesView, "_add_cancel_charge.html", form_name: :cancel_form, rule: @rule, cancel_charge: @cancel_charge, cancel_charge_driver_pay: @cancel_charge_driver_pay, amount_charged: @match.amount_charged, has_driver?: not is_nil(@match.driver) %>
            <% else %>
              <%= hidden_input :cancel_form, :cancel_charge, value: @cancel_charge %>
              <%= hidden_input :cancel_form, :cancel_charge_driver_pay, value: @cancel_charge_driver_pay %>
            <% end %>
            <%= if @match.contract && not Enum.empty?(@match.contract.cancellation_codes) do %>
              <div class="u-push__bottom--sm">
                <%= label :cancel_form, :code, "Cancellation Code" %>
                <%= select :cancel_form, :code,  Enum.map(@match.contract.cancellation_codes, &{&1.code, &1.code}), value: @code, "data-test-id": "cancellation-code-input" %>
              </div>
            <% else %>
              <%= hidden_input :cancel_form, :code, value: @code %>
            <% end %>
            <div class="u-pad__top--sm">
              <%= label :cancel_form, :cancel_reason, "Cancellation Reason", class: "optional" %>
              <%= textarea :cancel_form, :cancel_reason, value: @cancellation_reason %>
            </div>
          </div>
          <%= if @match.state == :completed do %>
            <p>IMPORTANT: If the Shipper has already been charged, this will need to be reversed in Stripe.</p>
          <% end %>
          <div class="u-pad__top u-text--center width--full">
            <button class="button button--primary">Cancel Match</button>
            <a class="button" onclick="" phx-keyup="close_modal" phx-key="Enter" tabindex=0 phx-click="close_modal">Cancel</a>
          </div>
        </form>
      </section>
    """
  end
end
