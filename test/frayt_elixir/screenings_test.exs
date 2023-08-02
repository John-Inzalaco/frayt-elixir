defmodule FraytElixir.ScreeningsTest do
  use FraytElixir.DataCase
  alias FraytElixir.Screenings
  alias FraytElixir.Screenings.BackgroundCheck
  alias FraytElixir.Drivers.Driver

  describe "start_background_check/2" do
    test "will succeed with valid params" do
      driver =
        %{vehicles: [vehicle]} =
        insert(:driver, english_proficiency: :beginner, market: build(:market))

      insert(:driver_document, driver: driver, type: :license)
      insert(:driver_document, driver: driver, type: :profile)
      insert(:vehicle_document, vehicle: vehicle, type: :back)
      insert(:vehicle_document, vehicle: vehicle, type: :cargo_area)
      insert(:vehicle_document, vehicle: vehicle, type: :drivers_side)
      insert(:vehicle_document, vehicle: vehicle, type: :front)
      insert(:vehicle_document, vehicle: vehicle, type: :passengers_side)
      insert(:vehicle_document, vehicle: vehicle, type: :insurance)
      insert(:vehicle_document, vehicle: vehicle, type: :registration)

      assert {:ok,
              %FraytElixir.Drivers.Driver{
                background_check: %FraytElixir.Screenings.BackgroundCheck{}
              }} = Screenings.start_background_check(driver)
    end

    test "will succeed with an initial background_check related" do
      %{id: background_check_id} =
        %{driver: driver} =
        insert(:background_check,
          driver: build(:driver),
          customer_id: "stripe_customer_id",
          transaction_id: "random_intent_id",
          state: :submitted
        )

      assert {:ok,
              %FraytElixir.Drivers.Driver{
                background_check: %FraytElixir.Screenings.BackgroundCheck{
                  id: ^background_check_id
                }
              }} = Screenings.start_background_check(driver)
    end
  end

  describe "authorize_background_check/2" do
    test "will fail when no payment_intent is associated with a background_check" do
      driver = insert(:driver)

      payment_params = %{
        intent_id: "random_intent_id",
        method_id: nil
      }

      assert {:error, "This payment method couldn't be confirmed."} =
               Screenings.authorize_background_check(driver, payment_params)
    end

    test "will succeed when a payment_intent is associated with a background_check" do
      %{id: background_check_id} =
        %{driver: driver} =
        insert(:background_check,
          driver: build(:driver),
          customer_id: "stripe_customer_id",
          transaction_id: "random_intent_id",
          state: :submitted
        )

      payment_params = %{
        intent_id: "random_intent_id",
        method_id: nil
      }

      assert {:ok,
              {%FraytElixir.Drivers.Driver{
                 background_check: %{id: ^background_check_id, state: :charged}
               },
               %Stripe.PaymentIntent{}}} =
               Screenings.authorize_background_check(driver, payment_params)
    end

    test "will succeed when no payment_intent is provided but method_id" do
      driver = insert(:driver)

      payment_params = %{
        method_id: "random_method_id"
      }

      assert {:ok, {%FraytElixir.Drivers.Driver{}, %Stripe.PaymentIntent{}}} =
               Screenings.authorize_background_check(driver, payment_params)
    end

    test "will succeed even without a payment_method specified" do
      driver = insert(:driver)

      payment_params = %{
        method_id: nil
      }

      assert {:ok, {%FraytElixir.Drivers.Driver{}, %Stripe.PaymentIntent{}}} =
               Screenings.authorize_background_check(driver, payment_params)
    end

    test "will fail when driver is invalid" do
      driver = insert(:driver, english_proficiency: nil)

      payment_params = %{
        method_id: nil
      }

      assert {:error, %{english_proficiency: ["can't be blank"]}} =
               Screenings.authorize_background_check(driver, payment_params)
    end
  end

  describe "get_background_check_by_turn_id" do
    test "finds background check" do
      bg_check = insert(:background_check, turn_id: "12345")

      assert %{id: bg_check_id} = Screenings.get_background_check_by_turn_id("12345")

      assert bg_check_id == bg_check.id
    end
  end

  describe "update_background_check_turn_status" do
    @attrs %{
      "dashboard_url" => "http://partners.turning.io/workers/here",
      "state" => "approved"
    }

    test "saves updated status and turn url" do
      background_check =
        insert(:background_check,
          turn_state: "pending",
          driver: build(:driver, state: :pending_approval)
        )

      assert {:ok,
              %Driver{
                state: :approved,
                background_check: %BackgroundCheck{
                  turn_state: "approved",
                  turn_url: "http://partners.turning.io/workers/here"
                }
              }} = Screenings.update_background_check_turn_status(background_check, @attrs)
    end

    test "rejects driver on turn rejection" do
      background_check =
        insert(:background_check,
          turn_state: "pending",
          driver: build(:driver, state: :pending_approval)
        )

      attrs = %{@attrs | "state" => "rejected"}

      assert {:ok,
              %Driver{
                state: :pending_approval,
                background_check: %BackgroundCheck{
                  turn_state: "rejected",
                  turn_url: "http://partners.turning.io/workers/here"
                }
              }} = Screenings.update_background_check_turn_status(background_check, attrs)
    end

    test "handles invalid data" do
      background_check =
        insert(:background_check,
          turn_state: "pending",
          driver: build(:driver, state: :pending_approval)
        )

      attrs = %{@attrs | "state" => 123}

      assert {:error, %Ecto.Changeset{errors: [turn_state: _]}} =
               Screenings.update_background_check_turn_status(background_check, attrs)
    end
  end

  describe "refresh_background_check_turn_status" do
    test "fetches status and updates " do
      driver =
        insert(:driver,
          state: :pending_approval,
          background_check:
            build(:background_check, turn_state: "pending", turn_id: "ABCD", driver: nil)
        )

      assert {:ok,
              %Driver{
                state: :approved,
                background_check: %BackgroundCheck{
                  turn_state: "approved",
                  turn_url: "https://partners.turning.io/workers/ABCD"
                }
              }} = Screenings.refresh_background_check_turn_status(driver)
    end
  end
end
