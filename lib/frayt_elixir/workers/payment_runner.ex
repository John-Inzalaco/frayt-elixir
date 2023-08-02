defmodule FraytElixir.Workers.PaymentRunner do
  use Oban.Worker, queue: :payments

  import Ecto.Query, warn: false

  alias FraytElixir.Repo
  alias FraytElixir.Shipment
  alias FraytElixir.Shipment.{Match, MatchStateTransition, MatchWorkflow}
  alias FraytElixir.Payments
  alias FraytElixir.Payments.PaymentTransaction

  @completed_transitions [:completed]
  @canceled_transitions [:canceled, :admin_canceled]

  @impl Oban.Worker
  def perform(_) do
    recent_match_cutoff = Timex.now() |> Timex.shift(days: -7)

    retrieve_completed_matches(recent_match_cutoff)
    |> Enum.each(&run_payment_transactions/1)

    retrieve_canceled_matches(recent_match_cutoff)
    |> Enum.each(&run_cancel_transactions/1)

    :ok
  end

  defp matches_transitioned_to(states, transitioned_since) do
    transition_query =
      from(
        mst in MatchStateTransition,
        where: mst.to in ^states and mst.inserted_at > ^transitioned_since,
        order_by: [desc: mst.inserted_at],
        distinct: mst.match_id
      )

    from(
      m in Match,
      join: mst in subquery(transition_query),
      on: mst.match_id == m.id,
      where: m.state in ^states,
      preload: [payment_transactions: [:driver_bonus]]
    )
  end

  def retrieve_canceled_matches(transitioned_since),
    do:
      matches_transitioned_to(@canceled_transitions, transitioned_since)
      |> where([m], m.cancel_charge > 0)
      |> Repo.all()

  def retrieve_completed_matches(transitioned_since),
    do:
      matches_transitioned_to(@completed_transitions, transitioned_since)
      |> Repo.all()

  def run_cancel_transactions(match) do
    run_cancel_charge(match)
    run_cancel_transfer(match)
  end

  def run_cancel_charge(match) do
    with true <- recent_match?(match, @canceled_transitions),
         true <- has_not_exceeded_limit?(match, :capture),
         {:ok, _match} <-
           Payments.does_not_have_successful_transaction_of_type(match, :capture, :cancel_charge),
         {:ok, _} <- Payments.run_cancel_charge(match) do
      {:ok, "Successfully charged"}
    else
      {:error, "match price has not changed"} ->
        {:ok, "match price has not changed"}

      {:error, "Match already has a successful capture transaction"} ->
        {:ok, "Match already has a successful capture transaction"}

      {:error, "Match already has a successful transfer transaction"} ->
        {:ok, "Match already has a successful transfer transaction"}

      {:error, %PaymentTransaction{} = pt} ->
        {:error, pt}

      reason ->
        {:error, reason}
    end
  end

  def run_cancel_transfer(match) do
    with true <- recent_match?(match, @canceled_transitions),
         true <- has_not_exceeded_limit?(match, :transfer),
         {:ok, _} <-
           Payments.does_not_have_successful_transaction_of_type(match, :transfer, :cancel_charge),
         {:ok, _} <- check_payout_delay(match, :cancel_charge),
         {:ok, _} <- Payments.transfer_driver_pay(match) do
      true
    else
      {:error, "Match already has a successful transfer transaction"} -> true
      _ -> false
    end
  end

  def run_payment_transactions(match) do
    with {:ok, _reason} <- run_capture(match), true <- run_transfer(match) do
      MatchWorkflow.charge_match(match)
    end
  end

  def run_capture(match) do
    match = preload_match(match)

    with true <- recent_match?(match, @completed_transitions),
         true <- has_not_exceeded_limit?(match, :capture),
         {:ok, _} <- Payments.charge_match(match) do
      {:ok, "Successfully charged"}
    else
      {:error, "match price has not changed"} ->
        {:ok, "match price has not changed"}

      {:error, "Match already has a successful transfer transaction"} ->
        {:ok, "Match already has a successful transfer transaction"}

      {:error, %PaymentTransaction{} = pt} ->
        {:error, pt}

      reason ->
        {:error, reason}
    end
  end

  def run_transfer(match) do
    match = preload_match(match)

    with true <- recent_match?(match, @completed_transitions),
         true <- has_not_exceeded_limit?(match, :transfer),
         {:ok, _} <- check_payout_delay(match, :charge),
         {:ok, _} <- Payments.transfer_driver_pay(match) do
      true
    else
      {:error, "Match already has a successful transfer transaction"} -> true
      _ -> false
    end
  end

  def has_not_exceeded_limit?(match, :capture),
    do: Payments.get_all_captures(match) |> check_limit()

  def has_not_exceeded_limit?(match, :transfer),
    do: Payments.get_all_transfers(match) |> check_limit()

  def recent_match?(%Match{} = match, states) do
    # WE ARE RELOADING A LOT OF THINGS WE DON'T NEED AT ALL!
    # WE SHOULD TRANSFORM THIS TO A `Matches.state_transitions`
    %{state_transitions: state_transitions} = preload_match(match)

    latest_transition =
      state_transitions
      |> Enum.filter(&(&1.to in states))
      |> Enum.sort(&(Timex.compare(&1.inserted_at, &2.inserted_at) == 1))
      |> List.first()

    case latest_transition do
      %{inserted_at: inserted_at} ->
        compare_result =
          Timex.now()
          |> Timex.shift(days: -7)
          |> Timex.compare(inserted_at)

        compare_result == -1 or compare_result == 0

      _ ->
        false
    end
  end

  defp check_limit(payments) do
    if Enum.any?(payments, &(&1.status == "succeeded")) do
      true
    else
      failed_payments =
        payments
        |> Enum.filter(&(&1.status != "succeeded"))
        |> Enum.count()

      if failed_payments < get_config(:retry_payment_limit, 2),
        do: true,
        else: {:error, "exceeded limit of failed attempts"}
    end
  end

  defp check_payout_delay(match, :cancel_charge),
    do:
      Shipment.match_transitioned_at(match, [:canceled, :admin_canceled], :desc)
      |> check_payout_delay()

  defp check_payout_delay(match, :charge),
    do: Shipment.match_transitioned_at(match, :completed, :desc) |> check_payout_delay()

  defp check_payout_delay(transitioned_at) do
    hours_since_completion =
      Timex.now("Etc/UTC")
      |> Timex.diff(transitioned_at, :hours)

    payout_delay = get_config(:payout_delay, 12 * 3600) / 3600

    if hours_since_completion > payout_delay,
      do: {:ok, true},
      else: {:error, "12 hours have not elapsed"}
  end

  defp preload_match(match),
    do:
      match
      |> Repo.preload([
        :state_transitions,
        payment_transactions: [:driver_bonus],
        shipper: [location: :company]
      ])

  defp get_config(key, default) do
    Application.get_env(:frayt_elixir, __MODULE__, [])
    |> Keyword.get(key, default)
  end
end
