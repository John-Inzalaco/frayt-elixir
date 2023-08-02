defmodule FraytElixir.Shipment.PricingTest do
  use FraytElixir.DataCase

  alias FraytElixir.Shipment

  alias FraytElixir.Shipment.{
    Coupon,
    Match,
    MatchFee,
    Pricing,
    ShipperMatchCoupon
  }

  alias FraytElixir.CustomContracts.ContractFees

  describe "build_fee/3" do
    test "builds attrs for existing fee" do
      %{fees: [%{id: fee_id}]} =
        match =
        insert(:match,
          fees: [build(:match_fee, type: :holiday_fee, amount: 100, driver_amount: 75)]
        )

      assert %{
               id: fee_id,
               driver_amount: 190,
               amount: 200,
               type: :holiday_fee
             } ==
               ContractFees.build_fee(match, %{
                 type: :holiday_fee,
                 amount: 200,
                 driver_amount: 190
               })
    end

    test "builds attrs for new fee" do
      match = insert(:match, fees: [])

      assert %{
               driver_amount: 190,
               amount: 200,
               type: :holiday_fee
             } ==
               ContractFees.build_fee(match, %{
                 type: :holiday_fee,
                 amount: 200,
                 driver_amount: 190
               })
    end
  end

  describe "build_fees/3" do
    test "builds list of fees" do
      %{fees: [%{id: fee_id}, _]} =
        match =
        insert(:match,
          fees: [
            build(:match_fee, type: :holiday_fee, amount: 100, driver_amount: 75),
            build(:match_fee, type: :holiday_fee, amount: 20, driver_amount: 15)
          ]
        )

      assert [
               %{
                 id: fee_id,
                 driver_amount: 190,
                 amount: 200,
                 type: :holiday_fee
               }
             ] ==
               ContractFees.build_fees(
                 match,
                 [
                   %{
                     type: :holiday_fee,
                     amount: 200,
                     driver_amount: 190
                   },
                   nil
                 ]
               )
    end
  end

  describe "calculate_driver_total_pay" do
    test "calculates drivers total pay" do
      match = insert(:match, fees: [build(:match_fee, amount: 1000, driver_amount: 691)])

      assert 691 == Pricing.calculate_driver_total_pay(match)
    end

    test "calculates with additional fees" do
      match =
        insert(:match,
          fees: [
            build(:match_fee, amount: 1000, driver_amount: 633),
            build(:match_fee, amount: 2000, driver_amount: 1830)
          ]
        )

      assert 2463 == Pricing.calculate_driver_total_pay(match)
    end
  end

  describe "test coupons" do
    test "create_coupon/1 with valid data creates a coupon" do
      attrs = %{
        code: "10OFF",
        percentage: 10,
        start_date: ~N[2019-11-15 10:00:00],
        end_date: ~N[2020-11-15 10:00:00],
        price_minimum: 10,
        price_maximum: 100,
        use_limit: 1
      }

      assert {:ok, %Coupon{} = coupon} = Pricing.create_coupon(attrs)

      assert %{
               code: "10OFF",
               percentage: 10,
               price_maximum: 100,
               price_minimum: 10,
               use_limit: 1,
               start_date: ~U[2019-11-15 10:00:00Z],
               end_date: ~U[2020-11-15 10:00:00Z]
             } = Pricing.get_coupon!(coupon.id)
    end

    test "create_coupon/1 with no code returns error changeset" do
      attrs = %{
        percentage: 10
      }

      assert {:error, %Ecto.Changeset{}} = Pricing.create_coupon(attrs)
    end

    test "create_coupon/1 without percentage returns error changeset" do
      attrs = %{
        code: "10OFF"
      }

      assert {:error, %Ecto.Changeset{} = changeset} = Pricing.create_coupon(attrs)

      assert {_, [validation: :required]} = changeset.errors[:percentage]
    end

    test "create_coupon/1 with lower maximum than minimum returns error changeset" do
      attrs = %{
        code: "10OFF",
        percentage: 12,
        price_minimum: 21,
        price_maximum: 20
      }

      assert {:error, %Ecto.Changeset{} = changeset} = Pricing.create_coupon(attrs)

      assert {_, [{:validation, :number}, {:kind, :less_than_or_equal_to}, {:number, 20}]} =
               changeset.errors[:price_minimum]
    end

    test "create_coupon/1 with equal minimum and maximum creates coupon" do
      attrs = %{
        code: "10OFF",
        percentage: 12,
        price_minimum: 20,
        price_maximum: 20
      }

      assert {:ok, %Coupon{}} = Pricing.create_coupon(attrs)
    end

    test "create_coupon/1 with earlier end_date than start_date returns error changeset" do
      attrs = %{
        code: "10OFF",
        percentage: 12,
        start_date: DateTime.from_naive!(~N[2020-11-15 10:00:00], "Etc/UTC"),
        end_date: DateTime.from_naive!(~N[2019-11-15 10:00:00], "Etc/UTC")
      }

      assert {:error, %Ecto.Changeset{} = changeset} = Pricing.create_coupon(attrs)
      assert {"must be earlier than end date", _} = changeset.errors[:start_date]
    end

    test "create_coupon/1 with use_limit must fail when 0" do
      attrs = %{
        code: "10OFF",
        percentage: 12,
        use_limit: 0
      }

      assert {:error, %Ecto.Changeset{} = changeset} = Pricing.create_coupon(attrs)

      assert {_, [{:validation, :number}, {:kind, :greater_than}, {:number, 0}]} =
               changeset.errors[:use_limit]
    end

    test "create_coupon/1 with use_limit is okay with nil" do
      attrs = %{
        code: "10OFF",
        percentage: 12,
        use_limit: nil
      }

      assert {:ok, %Coupon{}} = Pricing.create_coupon(attrs)
    end

    test "get_coupon! returns the coupon with given id" do
      coupon = insert(:small_coupon)

      fetched_coupon = Pricing.get_coupon!(coupon.id)

      assert fetched_coupon.id == coupon.id
    end

    test "get_coupon_by_code finds coupon with valid code" do
      insert(:small_coupon)
      coupon_code = "10OFF"

      assert Pricing.get_coupon_by_code(coupon_code)
    end

    test "get_coupon_by_code does not find coupon with an invalid code" do
      insert(:small_coupon)
      coupon_code = "SOME_INVALID_CODE"

      coupon = Pricing.get_coupon_by_code(coupon_code)

      assert coupon == nil
    end

    test "get_coupon_by_code finds coupon with mixed case code" do
      insert(:small_coupon)
      coupon_code = " 10ofF "

      assert Pricing.get_coupon_by_code(coupon_code)
    end
  end

  describe "apply_coupon_changeset" do
    test "applies coupon" do
      %{id: match_id, shipper_id: shipper_id} = match = insert(:assigning_driver_match)
      %{id: coupon_id, code: code} = insert(:small_coupon)

      assert {:ok, match} = Pricing.apply_coupon_changeset(match, code) |> Repo.update()

      assert %Match{
               coupon: %Coupon{id: ^coupon_id},
               shipper_match_coupon: %ShipperMatchCoupon{
                 coupon_id: ^coupon_id,
                 match_id: ^match_id,
                 shipper_id: ^shipper_id
               }
             } = Repo.preload(match, :coupon)
    end

    test "removes coupon" do
      match = insert(:assigning_driver_match)
      coupon = insert(:small_coupon)

      assert {:ok, %Match{shipper_match_coupon: %ShipperMatchCoupon{id: smc_id}} = match} =
               Pricing.apply_coupon_changeset(match, coupon.code) |> Repo.update()

      assert {:ok, match} = Pricing.apply_coupon_changeset(match, "") |> Repo.update()

      assert %Match{shipper_match_coupon: nil} = match

      refute Repo.get(ShipperMatchCoupon, smc_id)
    end

    test "applies a different coupon" do
      shipper = insert(:shipper)
      match = insert(:over_50_base_price_match, shipper: shipper)
      coupon1 = insert(:small_coupon)
      coupon2 = insert(:coupon)

      assert {:ok, %Match{shipper_match_coupon: %ShipperMatchCoupon{id: smc_id}}} =
               Pricing.apply_coupon_changeset(match, coupon1.code) |> Repo.update()

      assert {:ok, %Match{shipper_match_coupon: %ShipperMatchCoupon{id: ^smc_id}}} =
               Pricing.apply_coupon_changeset(match, coupon2.code) |> Repo.update()

      fetched_match = Shipment.get_match!(match.id) |> Repo.preload(:coupon)
      assert fetched_match.coupon.id == coupon2.id
    end

    test "a shipper can only use a coupon code once" do
      shipper = insert(:shipper)
      match1 = insert(:over_50_base_price_match, shipper: shipper, state: "assigning_driver")
      match2 = insert(:over_50_base_price_match, shipper: shipper)
      coupon = insert(:small_coupon, use_limit: 1)

      assert {:ok, %Match{}} =
               Pricing.apply_coupon_changeset(match1, coupon.code) |> Repo.update()

      assert {:error, %Ecto.Changeset{changes: %{shipper_match_coupon: changeset}}} =
               Pricing.apply_coupon_changeset(match2, coupon.code) |> Repo.update()

      assert {"code has already been used", _} = changeset.errors[:coupon_id]
    end

    test "a shipper can apply a coupon code to new match if old match is still pending" do
      shipper = insert(:shipper)
      match1 = insert(:over_50_base_price_match, shipper: shipper, state: :pending)
      match2 = insert(:over_50_base_price_match, shipper: shipper, state: :pending)
      coupon = insert(:small_coupon)

      assert {:ok, %Match{}} =
               Pricing.apply_coupon_changeset(match1, coupon.code) |> Repo.update()

      assert {:ok, %Match{}} =
               Pricing.apply_coupon_changeset(match2, coupon.code) |> Repo.update()

      fetched_match1 = Shipment.get_match!(match1.id) |> Repo.preload(:coupon)
      fetched_match2 = Shipment.get_match!(match2.id) |> Repo.preload(:coupon)
      assert fetched_match1.coupon == coupon
      assert fetched_match2.coupon == coupon
    end

    test "a shipper can fail to apply a valid second coupon and still have the first coupon applied to a match" do
      shipper = insert(:shipper)
      match = insert(:over_50_base_price_match, shipper: shipper)
      coupon = insert(:small_coupon)
      invalid_coupon = insert(:large_coupon, price_maximum: 5000)

      assert {:ok, %Match{}} = Pricing.apply_coupon_changeset(match, coupon.code) |> Repo.update()

      assert {:error, %Ecto.Changeset{changes: %{shipper_match_coupon: changeset}}} =
               Pricing.apply_coupon_changeset(match, invalid_coupon.code) |> Repo.update()

      assert {"is invalid for orders above $%{max}", _} = changeset.errors[:coupon_id]

      fetched_match = Shipment.get_match!(match.id) |> Repo.preload(:coupon)
      assert fetched_match.coupon == coupon
    end

    test "a shipper can fail to apply an invalid second coupon and still have the first coupon applied to a match" do
      shipper = insert(:shipper)
      match = insert(:over_50_base_price_match, shipper: shipper)
      coupon = insert(:small_coupon)

      assert {:ok, %Match{}} = Pricing.apply_coupon_changeset(match, coupon.code) |> Repo.update()

      assert {:error, %Ecto.Changeset{changes: %{shipper_match_coupon: changeset}}} =
               Pricing.apply_coupon_changeset(match, "Bogus code") |> Repo.update()

      assert {"code is invalid", _} = changeset.errors[:coupon_id]

      fetched_match = Shipment.get_match!(match.id) |> Repo.preload(:coupon)
      assert fetched_match.coupon == coupon
    end

    test "a shipper can't apply a bogus code" do
      shipper = insert(:shipper)
      match = insert(:over_50_base_price_match, shipper: shipper)
      insert(:small_coupon)

      assert {:error, %Ecto.Changeset{changes: %{shipper_match_coupon: changeset}}} =
               Pricing.apply_coupon_changeset(match, "Bogus code") |> Repo.update()

      assert {"code is invalid", _} = changeset.errors[:coupon_id]

      fetched_match = Shipment.get_match!(match.id) |> Repo.preload(:coupon)
      assert fetched_match.coupon == nil
    end

    test "a different shipper can still use a coupon code" do
      coupon = insert(:small_coupon)
      shipper1 = insert(:shipper)
      shipper2 = insert(:shipper)
      match1 = insert(:over_50_base_price_match, shipper: shipper1)
      match2 = insert(:over_50_base_price_match, shipper: shipper2)

      assert {:ok, %Match{}} =
               Pricing.apply_coupon_changeset(match1, coupon.code) |> Repo.update()

      assert {:ok, %Match{}} =
               Pricing.apply_coupon_changeset(match2, coupon.code) |> Repo.update()
    end

    test "a logged out shipper can still use a coupon code" do
      coupon = insert(:small_coupon)
      match = insert(:over_50_base_price_match, shipper: nil)

      assert {:ok, %Match{}} = Pricing.apply_coupon_changeset(match, coupon.code) |> Repo.update()
    end
  end

  describe "validate_match_coupon" do
    test "succeeds on match with no coupon" do
      shipper = insert(:shipper)
      match = insert(:over_50_base_price_match, shipper: shipper, state: "assigning_driver")
      insert(:small_coupon)

      assert {:ok, nil} = Pricing.validate_match_coupon(match)
    end

    test "succeeds on match with valid coupon" do
      shipper = insert(:shipper)
      match = insert(:over_50_base_price_match, shipper: shipper, state: "assigning_driver")
      coupon = insert(:small_coupon)

      assert {:ok, %Match{}} = Pricing.apply_coupon_changeset(match, coupon.code) |> Repo.update()

      assert {:ok, %Coupon{}} = Pricing.validate_match_coupon(match)
    end

    test "fails on match when at coupon limit" do
      shipper = insert(:shipper)
      coupon = insert(:small_coupon, use_limit: 1)

      match1 = insert(:over_50_base_price_match, shipper: shipper, state: :pending)

      assert {:ok, %Match{}} =
               Pricing.apply_coupon_changeset(match1, coupon.code) |> Repo.update()

      match2 = insert(:over_50_base_price_match, shipper: shipper, state: "assigning_driver")

      assert {:ok, %Match{}} =
               Pricing.apply_coupon_changeset(match2, coupon.code) |> Repo.update()

      assert {:error, %Ecto.Changeset{} = changeset} = Pricing.validate_match_coupon(match1)
      assert {"code has already been used", _} = changeset.errors[:coupon_id]
    end

    test "succeeds on multiple uses with no use limit" do
      shipper = insert(:shipper)
      coupon = insert(:small_coupon)

      match1 = insert(:over_50_base_price_match, shipper: shipper, state: :pending)

      assert {:ok, %Match{}} =
               Pricing.apply_coupon_changeset(match1, coupon.code) |> Repo.update()

      match2 = insert(:over_50_base_price_match, shipper: shipper, state: "assigning_driver")

      assert {:ok, %Match{}} =
               Pricing.apply_coupon_changeset(match2, coupon.code) |> Repo.update()

      assert {:ok, %Coupon{}} = Pricing.validate_match_coupon(match2)
    end

    test "succeeds when between start and end date" do
      now = DateTime.utc_now()
      shipper = insert(:shipper)

      coupon =
        insert(:small_coupon, start_date: DateTime.add(now, -60), end_date: DateTime.add(now, 60))

      match =
        insert(:over_50_base_price_match,
          shipper_match_coupon: build(:shipper_match_coupon, shipper: shipper, coupon: coupon),
          state: "assigning_driver"
        )

      assert {:ok, %Coupon{}} = Pricing.validate_match_coupon(match)
    end

    test "fails when before start date" do
      now = DateTime.utc_now()
      shipper = insert(:shipper)

      coupon = insert(:small_coupon, start_date: DateTime.add(now, 60))

      match =
        insert(:over_50_base_price_match,
          shipper_match_coupon: build(:shipper_match_coupon, shipper: shipper, coupon: coupon),
          state: "assigning_driver"
        )

      assert {:error, %Ecto.Changeset{} = changeset} = Pricing.validate_match_coupon(match)
      assert {"is not active", _} = changeset.errors[:coupon_id]
    end

    test "fails when after end date" do
      now = DateTime.utc_now()
      shipper = insert(:shipper)

      coupon = insert(:small_coupon, end_date: DateTime.add(now, -60))

      match =
        insert(:over_50_base_price_match,
          shipper_match_coupon: build(:shipper_match_coupon, shipper: shipper, coupon: coupon),
          state: "assigning_driver"
        )

      assert {:error, %Ecto.Changeset{} = changeset} = Pricing.validate_match_coupon(match)
      assert {"is expired", _} = changeset.errors[:coupon_id]
    end

    test "succeeds when between min and max price" do
      shipper = insert(:shipper)

      coupon = insert(:small_coupon, price_minimum: 10_00, price_maximum: 100_00)

      match =
        insert(:over_50_base_price_match,
          shipper_match_coupon: build(:shipper_match_coupon, shipper: shipper, coupon: coupon),
          state: "assigning_driver"
        )

      assert {:ok, %Coupon{}} = Pricing.validate_match_coupon(match)
    end

    test "fails when less than min price" do
      shipper = insert(:shipper)

      coupon = insert(:small_coupon, price_minimum: 100_00)

      match =
        insert(:over_50_base_price_match,
          shipper_match_coupon: build(:shipper_match_coupon, shipper: shipper, coupon: coupon),
          state: "assigning_driver"
        )

      assert {:error, %Ecto.Changeset{} = changeset} = Pricing.validate_match_coupon(match)
      assert {"is invalid for orders below $%{min}", [min: 100.0]} = changeset.errors[:coupon_id]
    end

    test "fails when more than max price" do
      shipper = insert(:shipper)

      coupon = insert(:small_coupon, price_maximum: 10_00)

      match =
        insert(:over_50_base_price_match,
          shipper_match_coupon: build(:shipper_match_coupon, shipper: shipper, coupon: coupon),
          state: "assigning_driver"
        )

      assert {:error, %Ecto.Changeset{} = changeset} = Pricing.validate_match_coupon(match)
      assert {"is invalid for orders above $%{max}", [max: 10.0]} = changeset.errors[:coupon_id]
    end
  end

  describe "subtotal" do
    test "calculates subtotal" do
      match =
        insert(:match,
          fees: [
            build(:match_fee, amount: 2000, driver_amount: 1500),
            build(:match_fee, amount: 1000, driver_amount: 500),
            build(:match_fee, amount: 1200, driver_amount: 0),
            build(:match_fee, amount: 0, driver_amount: 100)
          ]
        )

      assert Pricing.subtotal(match) == 4200
    end
  end

  describe "total_price" do
    test "calculates total price" do
      %Match{fees: [%MatchFee{amount: base_fee}]} = match = insert(:match)
      assert {^base_fee, 0} = Pricing.total_price(match)
    end

    test "calculates with inapplicable market markup" do
      insert(:market_zip_code, zip: "12345", market: build(:market, markup: 1.5))

      match =
        insert(:match,
          fees: [build(:match_fee, amount: 1000)],
          origin_address: build(:address, zip: "54321")
        )

      assert {1000, 0} = Pricing.total_price(match)
    end

    test "calculates with market markup and fees" do
      insert(:market_zip_code, zip: "12345", market: build(:market, markup: 1.5))

      match =
        insert(:match,
          origin_address: build(:address, zip: "12345"),
          fees: [
            build(:match_fee, amount: 1000),
            build(:match_fee, amount: 50),
            build(:match_fee, amount: 820)
          ]
        )

      assert {1870, 0} = Pricing.total_price(match)
    end

    test "calculates with coupon and fees" do
      match =
        insert(:match,
          fees: [
            build(:match_fee, type: :base_fee, amount: 900, driver_amount: 600),
            build(:match_fee, amount: 1000, driver_amount: 750),
            build(:match_fee, amount: 100, driver_amount: 75),
            build(:match_fee, amount: 50, driver_amount: 0),
            build(:match_fee, amount: 820, driver_amount: 820),
            build(:match_fee, amount: 750, driver_amount: 750),
            build(:match_fee, amount: 600, driver_amount: 500)
          ]
        )

      coupon = insert(:coupon, percentage: 10)
      insert(:shipper_match_coupon, match: match, shipper: match.shipper, coupon: coupon)
      assert {3798, 422} = Pricing.total_price(match)
    end

    test "calculates with max discount coupon" do
      match =
        insert(:match,
          fees: [
            build(:match_fee, type: :base_fee, amount: 900, driver_amount: 600)
          ]
        )

      coupon = insert(:coupon, percentage: 10, discount_maximum: 10)
      insert(:shipper_match_coupon, match: match, shipper: match.shipper, coupon: coupon)
      assert {890, 10} = Pricing.total_price(match)
    end
  end

  describe "calculate_pricing" do
    test "returns a changeset" do
      match = insert(:match)

      assert %Ecto.Changeset{changes: %{driver_cut: _, driver_fees: _, fees: _, match_stops: _}} =
               Pricing.calculate_pricing(match)
    end
  end

  describe "calculate_expected_toll" do
    defp build_match(stop_count, origin_address \\ "Somewhere"),
      do:
        insert(:match,
          origin_address: build(:address, formatted_address: origin_address),
          match_stops: build_list(stop_count, :match_stop)
        )

    test "for match with invalid origin address returns 0" do
      match = build_match(1, "invalid_address")

      assert {:ok, 0} = Pricing.calculate_expected_toll(match)
    end

    test "for match with no stops returns 0" do
      match = build_match(0)

      assert {:ok, 0} = Pricing.calculate_expected_toll(match)
    end

    test "for match with valid origin and stop returns correct amount" do
      match = build_match(1)

      assert {:ok, 1830} = Pricing.calculate_expected_toll(match)
    end
  end

  describe "test calculate_driver_fees/1" do
    test "When no fees is received then the driver fees is base price" do
      match =
        insert(:match,
          fees: []
        )

      assert 30 == ContractFees.calculate_driver_fees(match)
    end

    test "When fees is present then the driver fees in sum of amount + base price" do
      match =
        insert(:match,
          fees: [
            build(:match_fee, amount: 1000, driver_amount: 0)
          ]
        )

      # (1000 * 0.029) + 30 =
      assert 59 == ContractFees.calculate_driver_fees(match)

      match =
        insert(:match,
          fees: [
            build(:match_fee, amount: 1000, driver_amount: 0),
            build(:match_fee, amount: 1000, driver_amount: 0)
          ]
        )

      # (1000 * 0.029) + (1000 * 0.029) + 30 =
      assert 88 == ContractFees.calculate_driver_fees(match)
    end

    test "Shipper belongs to a with account billing company the driver fees is zero" do
      company = insert(:company, account_billing_enabled: true)
      location = insert(:location, company: company)

      shipper =
        insert(:shipper,
          first_name: "Abe",
          last_name: "Miller",
          location: location
        )

      match =
        insert(:match,
          fees: [
            build(:match_fee, amount: 100_00, driver_amount: 0)
          ],
          shipper: shipper
        )

      assert 0 == ContractFees.calculate_driver_fees(match)
    end

    test "Shipper belongs to a company without account billing the driver fees is base" do
      company = insert(:company, account_billing_enabled: false)
      location = insert(:location, company: company)

      shipper =
        insert(:shipper,
          first_name: "Abe",
          last_name: "Miller",
          location: location
        )

      match =
        insert(:match,
          fees: [
            build(:match_fee, amount: 0, driver_amount: 0)
          ],
          shipper: shipper
        )

      assert 30 == ContractFees.calculate_driver_fees(match)
    end
  end
end
