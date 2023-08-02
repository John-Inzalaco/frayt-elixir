defmodule FraytElixir.ReleaseTasks do
  @moduledoc """
  This module contains tasks designed to be run in the console in deployed environment
  """

  import FraytElixir.Factory
  import Ecto.Query

  alias FraytElixir.Repo

  alias FraytElixir.Accounts.Shipper

  alias FraytElixir.Shipment.{
    Match,
    Address,
    MatchStopItem
  }

  alias FraytElixir.Payments.PaymentTransaction
  alias FraytElixir.Drivers.{Driver, DriverLocation}
  require Logger

  @doc """
  **Warning: DO NOT USE IN PRODUCTION**

  This functional will remove OneSignal ids from all Drivers and Shippers. It is
  designed to be used in staging to prevent notifications from being sent out to
  actual users after production data is loaded.
  """
  def wipe_one_signal_ids do
    Repo.update_all(Driver, set: [one_signal_id: nil])
    Repo.update_all(Shipper, set: [one_signal_id: nil])
  end

  @doc """
  Create an admin account with specified email and password.
  """
  def create_admin(email, password) do
    insert(:admin_user, user: build(:user, email: email, password: password))
  end

  @doc """
  Creates a series of drivers (without seller accounts) from `start` to `stop` where
  start and stop are integers. Each driver will have an email of the form `driver<i>@frayt.com`
  """
  def create_drivers(start, stop) do
    range = Range.new(start, stop)

    range
    |> Enum.each(fn i -> insert(:driver, user: build(:user, email: "driver#{i}@frayt.com")) end)
  end

  def sanitize_addresses_state do
    Repo.all(from(a in Address))
    |> Enum.each(fn address ->
      attrs = Address.get_state_attrs(address.state)

      address
      |> Ecto.Changeset.cast(attrs, [:state, :state_code])
      |> Repo.update!()
    end)
  end

  def remove_oldest_driver_locations(limit \\ 300_000) do
    two_months_ago =
      DateTime.utc_now()
      |> DateTime.add(-60 * 24 * 60 * 60)

    from(dl in DriverLocation,
      join:
        safe_dl in subquery(
          from(dl0 in DriverLocation,
            left_join: d in Driver,
            on: d.current_location_id == dl0.id,
            where: is_nil(d),
            order_by: dl0.inserted_at,
            limit: ^limit
          )
        ),
      on: safe_dl.id == dl.id,
      where: dl.inserted_at <= ^two_months_ago
    )
    |> Repo.delete_all()
  end

  def list_match_items(shortcode) do
    %Match{match_stops: match_stops} =
      Repo.get_by(Match, shortcode: shortcode) |> Repo.preload(match_stops: [:items])

    match_stops
    |> Enum.map(
      &(&1.items
        |> Enum.map(fn %{id: id, weight: weight, pieces: pieces} ->
          %{id: id, weight: weight, pieces: pieces}
        end))
    )
  end

  def change_match_item(item_id, pieces, weight) do
    Repo.get!(MatchStopItem, item_id)
    |> Ecto.Changeset.cast(%{pieces: pieces, weight: weight}, [:pieces, :weight])
    |> Repo.update()
  end

  def list_match_payments(shortcode) do
    %Match{payment_transactions: payment_transactions} =
      Repo.get_by(Match, shortcode: shortcode) |> Repo.preload(:payment_transactions)

    payment_transactions
    |> Enum.map(fn %{id: id, transaction_type: transaction_type, status: status, amount: amount} ->
      %{id: id, transaction_type: transaction_type, status: status, amount: amount}
    end)
  end

  def change_payment(payment_id, status, amount) when status in ["succeeded", "error"] do
    Repo.get!(PaymentTransaction, payment_id)
    |> Ecto.Changeset.cast(%{status: status, amount: amount}, [:status, :amount])
    |> Repo.update()
  end

  def change_payment(_payment_id, status, _amount) do
    IO.puts("Invalid status of #{status}. Must be either 'succeeded' or 'error'")
  end
end
