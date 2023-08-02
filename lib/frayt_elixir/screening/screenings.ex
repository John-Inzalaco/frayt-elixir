defmodule FraytElixir.Screenings do
  @moduledoc """
  The screening.
  """

  require Logger
  import Ecto.Query, warn: false
  alias FraytElixir.Notifications.DriverNotification
  alias FraytElixir.Screenings.BackgroundCheck
  alias FraytElixir.Repo
  alias FraytElixir.Payments
  alias FraytElixir.Drivers
  alias FraytElixir.Utils

  @screening_provider Application.compile_env(
                        :frayt_elixir,
                        [__MODULE__, :screening_provider],
                        FraytElixir.Screenings.Turn
                      )

  def create_background_check(
        driver_id,
        stripe_customer_id,
        intent_id,
        amount \\ 3500,
        state \\ :pending
      ) do
    %{
      driver_id: driver_id,
      customer_id: stripe_customer_id,
      transaction_id: intent_id,
      state: state,
      amount_charged: amount
    }
    |> create_background_check()
  end

  def create_background_check(attrs \\ %{}) do
    %BackgroundCheck{}
    |> BackgroundCheck.changeset(attrs)
    |> Repo.insert()
  end

  def update_background_check(%BackgroundCheck{} = background_check, attrs \\ %{}) do
    background_check
    |> BackgroundCheck.changeset(attrs)
    |> Repo.update()
  end

  def get_background_check_by_turn_id(turn_id) do
    Repo.get_by!(BackgroundCheck, turn_id: turn_id)
  end

  def get_background_check_by_intent_id(id) do
    Repo.get_by(BackgroundCheck, transaction_id: id)
  end

  def latest_background_check_query do
    from(
      d in subquery(
        from(b in BackgroundCheck,
          order_by: [desc: b.inserted_at]
        )
      )
    )
  end

  def refresh_background_check_turn_status(driver) do
    %{background_check: background_check} = driver
    background_check = %{background_check | driver: driver}

    with {:ok, response} <- @screening_provider.get_worker_status(background_check.turn_id) do
      update_background_check_turn_status(background_check, response)
    end
  end

  def update_background_check_turn_status(background_check, %{
        "dashboard_url" => turn_url,
        "state" => state
      }) do
    attrs = %{
      turn_state: state,
      turn_url: turn_url
    }

    with {:ok, background_check} <- update_background_check(background_check, attrs) do
      background_check = Repo.preload(background_check, driver: [:user])
      driver = %{background_check.driver | background_check: background_check}

      case state do
        "approved" ->
          DriverNotification.send_approval_letter_email(driver)
          Drivers.update_driver_state(driver, :approved)

        _ ->
          {:ok, driver}
      end
    end
  end

  def authorize_background_check(driver, attrs) do
    Repo.transaction(fn ->
      with {:ok, payment_intent, background_check} <-
             Payments.charge_background_check(driver, attrs),
           {:ok, driver} <-
             Drivers.complete_driver_application(driver),
           {:ok, driver} <- Drivers.update_driver_state(driver, :pending_approval) do
        driver = %{driver | background_check: background_check}

        {driver, payment_intent}
      else
        {:error, _, %Ecto.Changeset{} = error} ->
          Repo.rollback(error)

        {:error, _, error} when is_binary(error) ->
          Repo.rollback(error)

        {:error, %Ecto.Changeset{} = error} ->
          Utils.convert_changeset_error(error)
          |> Repo.rollback()

        {:error, error} when is_binary(error) ->
          Repo.rollback(error)

        {:error, error} ->
          Logger.error(
            "An unexpected error has occurred creating or authorizing a background check: #{inspect(error)}"
          )

          Repo.rollback("An unexpected error has occurred")
      end
    end)
  end

  def start_background_check(driver) do
    driver =
      case Repo.preload(driver, [:user, :background_check]) do
        %{background_check: nil} ->
          {:ok, bg_check} = create_background_check(%{state: :skipped, driver_id: driver.id})

          %{driver | background_check: bg_check}

        d ->
          d
      end

    attrs = %{
      first_name: driver.first_name,
      last_name: driver.last_name,
      email: driver.user.email,
      phone_number:
        driver.phone_number &&
          ExPhoneNumber.format(driver.phone_number, :e164) |> String.replace("+", ""),
      email_candidate: true,
      callback_url: FraytElixirWeb.Endpoint.url() <> "/webhooks/turn",
      reference_id: driver.background_check.id,
      do_checks: true
    }

    with {:ok, result} <- @screening_provider.search_async(attrs) do
      %{"worker_id" => worker_id, "candidate_consent_url" => turn_consent_url} = result

      bg_check_attrs = %{
        turn_state: "requested",
        turn_id: worker_id,
        turn_consent_url: turn_consent_url
      }

      with {:ok, background_check} <-
             update_background_check(driver.background_check, bg_check_attrs),
           {:ok, driver} <- Drivers.update_driver_state(driver, :screening) do
        {:ok, %{driver | background_check: background_check}}
      end
    end
  end
end
