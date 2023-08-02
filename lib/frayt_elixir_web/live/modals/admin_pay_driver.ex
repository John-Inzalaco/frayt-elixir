defmodule FraytElixirWeb.AdminPayDriver do
  use Phoenix.LiveView
  alias FraytElixir.Repo
  alias FraytElixir.Drivers
  alias FraytElixir.Payments
  import FraytElixirWeb.DisplayFunctions, only: [convert_string_to_cents: 1]

  @empty_amount ["", "0", "0.0", "0.00"]
  @empty_form %{"amount" => nil, "match_id" => nil, "notes" => nil}

  def mount(_params, %{"current_user" => current_user, "driver" => driver}, socket) do
    {:ok,
     assign(socket, %{
       driver: driver,
       current_user: current_user,
       errors: [],
       form: @empty_form,
       success: nil,
       found_ids: nil
     })}
  end

  def handle_event("close_modal", _event, socket) do
    send(socket.parent_pid, :close_modal)
    {:noreply, socket}
  end

  def handle_event("choose_id_" <> match_id, _event, socket) do
    {:noreply,
     assign(socket, %{
       form: Map.put(socket.assigns.form, "match_id", match_id),
       found_ids: nil,
       errors: Keyword.delete(socket.assigns.errors, :match_id)
     })}
  end

  def handle_event(
        "pay_bonus",
        %{"pay_driver_bonus" => %{"match_id" => "", "amount" => amount} = driver_bonus_form},
        socket
      )
      when amount in @empty_amount do
    {:noreply,
     assign(socket, %{
       errors: [{:amount, {"Enter a valid amount"}}],
       found_ids: nil,
       success: nil,
       form: driver_bonus_form
     })}
  end

  def handle_event(
        "pay_bonus",
        %{"pay_driver_bonus" => %{"match_id" => "", "amount" => amount, "notes" => notes}},
        socket
      ) do
    Payments.transfer_driver_bonus(%{
      driver: socket.assigns.driver,
      admin_user: socket.assigns.current_user.admin,
      amount: convert_string_to_cents(amount),
      notes: notes,
      match: nil
    })

    {:noreply,
     assign(socket, %{
       form: @empty_form,
       found_ids: nil,
       success: "Bonus payment submitted",
       errors: []
     })}
  end

  def handle_event(
        "pay_bonus",
        %{
          "pay_driver_bonus" =>
            %{"match_id" => match_id, "amount" => amount, "notes" => notes} = driver_bonus_form
        },
        socket
      )
      when amount in @empty_amount do
    socket =
      assign(socket, %{
        success: nil,
        found_ids: nil,
        form: driver_bonus_form,
        errors: [{:amount, {"Enter a valid amount"}}]
      })

    pay_driver_bonus(socket, match_id, amount, notes)
  end

  def handle_event(
        "pay_bonus",
        %{
          "pay_driver_bonus" =>
            %{"match_id" => match_id, "amount" => amount, "notes" => notes} = driver_bonus_form
        },
        socket
      ) do
    assign(socket, %{form: driver_bonus_form, found_ids: nil, errors: [], success: nil})
    |> pay_driver_bonus(match_id, amount, notes)
  end

  def pay_driver_bonus(socket, match_id, amount, notes) do
    case Drivers.validate_match_assignment(socket.assigns.driver.id, match_id) do
      {:ok, match_id} ->
        complete_transfer(socket, match_id, amount, notes)

      {:error, "match not found"} ->
        {:noreply,
         assign(socket, %{errors: socket.assigns.errors ++ [{:match_id, {"Match not found"}}]})}

      {:error, "multiple matches found", match_ids} ->
        {:noreply,
         assign(socket, %{
           found_ids: match_ids,
           errors: socket.assigns.errors ++ [{:match_id, {"Multiple matches found"}}]
         })}
    end
  end

  def complete_transfer(%{assigns: %{errors: [_ | _]}} = socket, _match_id, _amount, _notes),
    do: {:noreply, socket}

  def complete_transfer(socket, match_id, amount, notes) do
    Payments.transfer_driver_bonus(%{
      driver: socket.assigns.driver,
      admin_user: socket.assigns.current_user.admin,
      amount: convert_string_to_cents(amount),
      notes: notes,
      match: match_id && Repo.get(FraytElixir.Shipment.Match, match_id)
    })

    {:noreply, assign(socket, %{form: @empty_form, success: "Bonus payment submitted"})}
  end

  def render(assigns) do
    FraytElixirWeb.Admin.DriversView.render("pay_driver_bonus.html", assigns)
  end
end
