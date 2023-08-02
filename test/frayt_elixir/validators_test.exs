defmodule FraytElixir.ValidatorsTest do
  use FraytElixir.DataCase

  alias Ecto.Changeset
  import Ecto.Changeset
  import FraytElixir.Validators

  alias FraytElixir.Shipment.Match
  alias FraytElixir.Type.PhoneNumber

  defmodule Coupon do
    use FraytElixir.Schema

    schema "coupons" do
      field :code, :string
      field :start_date, :utc_datetime
      field :end_date, :utc_datetime
      field :price_minimum, :integer
      field :price_maximum, :integer
      field :old_coupon_id, :string
      field :phone_number, PhoneNumber
    end
  end

  defp changeset, do: changeset(%{})
  defp changeset(attrs), do: changeset(%Coupon{}, attrs)

  defp changeset(schema, attrs),
    do:
      changeset(schema, attrs, [
        :old_coupon_id,
        :code,
        :start_date,
        :end_date,
        :price_minimum,
        :price_maximum
      ])

  defp changeset(schema, attrs, permitted), do: cast(schema, attrs, permitted)

  describe "validate_assoc_length" do
    defp match_changeset(attrs),
      do:
        %Match{match_stops: []}
        |> cast(attrs, [])
        |> cast_assoc(:match_stops)

    test "validates above min" do
      changeset =
        match_changeset(%{match_stops: []})
        |> validate_assoc_length(:match_stops, min: 1)

      refute changeset.valid?

      assert {_, [count: 1, validation: :assoc_length, kind: :min]} =
               changeset.errors[:match_stops]
    end

    test "validates below max" do
      changeset =
        match_changeset(%{match_stops: [%{}, %{}]})
        |> validate_assoc_length(:match_stops, max: 1)

      refute changeset.valid?

      assert {_, [count: 1, validation: :assoc_length, kind: :max]} =
               changeset.errors[:match_stops]
    end

    test "validates with filter" do
      changeset =
        match_changeset(%{match_stops: [%{from: :accepted}, %{from: :assigning_driver}]})
        |> validate_assoc_length(
          :match_stops,
          [min: 2, message: "should have at least %{count} accepted stop"],
          &(&1.id == :accepted)
        )

      refute changeset.valid?

      assert {"should have at least %{count} accepted stop",
              [count: 2, validation: :assoc_length, kind: :min]} = changeset.errors[:match_stops]
    end

    test "validates successfully" do
      changeset =
        match_changeset(%{match_stops: [%{}]})
        |> validate_assoc_length(:match_stops, min: 1, max: 1)

      assert changeset.valid?
    end
  end

  describe "validate_some_required" do
    test "validates at least on is present" do
      changeset =
        changeset(%{})
        |> validate_some_required([:price_minimum, :price_maximum])

      refute changeset.valid?

      assert {_, [validation: :some_required, of: [:price_minimum, :price_maximum]]} =
               changeset.errors[:price_minimum]
    end

    test "succeeds if one or more is present" do
      %Changeset{valid?: true} =
        changeset(%{price_minimum: 1})
        |> validate_some_required([:price_minimum, :price_maximum])

      %Changeset{valid?: true} =
        changeset(%{price_maximum: 1, price_minimum: 0})
        |> validate_some_required([:price_minimum, :price_maximum])
    end
  end

  describe "validate_one_of_present" do
    test "validates precense of only one" do
      changeset =
        changeset(%{price_minimum: 12, price_maximum: 10})
        |> validate_one_of_present([:price_minimum, :price_maximum])

      refute changeset.valid?

      assert {_, [validation: :one_of_present, among: [:price_minimum, :price_maximum]]} =
               changeset.errors[:price_minimum]
    end

    test "validates precense of at least one" do
      changeset =
        changeset()
        |> validate_one_of_present([:price_minimum, :price_maximum])

      refute changeset.valid?

      assert {_, [validation: :one_of_present, among: [:price_minimum, :price_maximum]]} =
               changeset.errors[:price_minimum]
    end
  end

  describe "validate_number_by_field" do
    test "validates field references as numbers" do
      changeset =
        changeset(%{price_minimum: 12, price_maximum: 10})
        |> validate_number_by_field(:price_minimum, less_than: :price_maximum)

      refute changeset.valid?

      assert {_, [validation: :number, kind: :less_than, number: 10]} =
               changeset.errors[:price_minimum]
    end

    test "validates numbers as numbers" do
      changeset =
        changeset(%{price_minimum: 12, price_maximum: 14})
        |> validate_number_by_field(:price_minimum, less_than: :price_maximum, greater_than: 12)

      refute changeset.valid?

      assert {_, [validation: :number, kind: :greater_than, number: 12]} =
               changeset.errors[:price_minimum]
    end
  end

  describe "validate_empty" do
    test "validates empty" do
      changeset =
        changeset(%{code: "string"})
        |> validate_empty(:code)

      refute changeset.valid?

      assert {_, [validation: :empty]} = changeset.errors[:code]
    end

    test "succeeds when empty" do
      changeset =
        changeset(%{code: nil})
        |> validate_empty(:code)

      assert changeset.valid?
    end
  end

  describe "validate_when" do
    test "validates using empty" do
      changeset =
        changeset(%{code: "string", price_minimum: 1})
        |> validate_when(:code, [{:price_minimum, :equal_to, 1}], &validate_empty/3)

      refute changeset.valid?

      assert {_, [validation: :empty]} = changeset.errors[:code]
    end

    test "succeeds validating using empty" do
      changeset =
        changeset(%{code: nil, price_minimum: 1})
        |> validate_when(:code, [{:price_minimum, :equal_to, 1}], &validate_empty/3)

      assert changeset.valid?
    end

    test "validates with no field using empty" do
      changeset = changeset(%{code: "string", price_minimum: 1})

      changeset =
        validate_when(changeset, [{:price_minimum, :equal_to, 1}], fn cs ->
          validate_empty(cs, :code)
        end)

      refute changeset.valid?
    end

    test "succeeds validation with no field using empty" do
      changeset = changeset(%{code: nil, price_minimum: 1})

      changeset =
        validate_when(changeset, [{:price_minimum, :equal_to, 1}], fn cs ->
          validate_empty(cs, :code)
        end)

      assert changeset.valid?
    end
  end

  describe "validate_required_when" do
    test "requires when target matches value" do
      changeset =
        changeset(%{price_minimum: nil, code: "string"})
        |> validate_required_when(:price_minimum, [{:code, :equal_to, "string"}])

      refute changeset.valid?

      assert {_, [validation: :required]} = changeset.errors[:price_minimum]
    end

    test "requires when target does not match value and spec is :not_equal_to" do
      changeset =
        changeset(%{price_minimum: nil, code: "string"})
        |> validate_required_when(:price_minimum, [{:code, :not_equal_to, "number"}])

      refute changeset.valid?
      assert {_, [validation: :required]} = changeset.errors[:price_minimum]
    end

    test "requires when multiple targets match their specs" do
      changeset =
        changeset(%{price_minimum: nil, code: "string", old_coupon_id: "dafslfuhasjdfh"})
        |> validate_required_when(:price_minimum, [
          {:code, :equal_to, "string"},
          {:old_coupon_id, :not_equal_to, "afssdf"}
        ])

      refute changeset.valid?
      assert {_, [validation: :required]} = changeset.errors[:price_minimum]
    end

    test "does not require when target does not match value" do
      changeset =
        changeset(%{price_minimum: nil, code: "string"})
        |> validate_required_when(:price_minimum, [{:code, :equal_to, "number"}])

      assert changeset.valid?
    end

    test "does not require when some targets don't match their specs" do
      changeset =
        changeset(%{price_minimum: nil, code: "string"})
        |> validate_required_when(:price_minimum, [
          {:code, :equal_to, "string"},
          {:old_coupon_id, :equal_to, "afssdf"}
        ])

      assert changeset.valid?
    end
  end

  describe "validate_time/4" do
    setup do
      [
        changeset: changeset(%{start_date: ~U[2020-01-01 12:00:00Z]})
      ]
    end

    test "validates less than", %{changeset: cs} do
      assert %Changeset{valid?: true} = validate_time(cs, :start_date, less_than: ~T[12:00:01])

      assert %Changeset{
               valid?: false,
               errors: [
                 start_date:
                   {"must be before %{time}",
                    [time: ~T[12:00:00], validation: :time, kind: :less_than]}
               ]
             } = validate_time(cs, :start_date, less_than: ~T[12:00:00])

      assert %Changeset{
               valid?: false,
               errors: [
                 start_date:
                   {"must be before %{time}",
                    [time: ~T[11:59:59], validation: :time, kind: :less_than]}
               ]
             } = validate_time(cs, :start_date, less_than: ~T[11:59:59])
    end

    test "validates less than or equal to", %{changeset: cs} do
      assert %Changeset{valid?: true} =
               validate_time(cs, :start_date, less_than_or_equal_to: ~T[12:00:01])

      assert %Changeset{valid?: true} =
               validate_time(cs, :start_date, less_than_or_equal_to: ~T[12:00:00])

      assert %Changeset{
               valid?: false,
               errors: [
                 start_date:
                   {"must be at or before %{time}",
                    [time: ~T[11:59:59], validation: :time, kind: :less_than_or_equal_to]}
               ]
             } = validate_time(cs, :start_date, less_than_or_equal_to: ~T[11:59:59])
    end

    test "validates greater than", %{changeset: cs} do
      assert %Changeset{valid?: true} = validate_time(cs, :start_date, greater_than: ~T[11:59:59])

      assert %Changeset{
               valid?: false,
               errors: [
                 start_date:
                   {"must be after %{time}",
                    [time: ~T[12:00:00], validation: :time, kind: :greater_than]}
               ]
             } = validate_time(cs, :start_date, greater_than: ~T[12:00:00])

      assert %Changeset{
               valid?: false,
               errors: [
                 start_date:
                   {"must be after %{time}",
                    [time: ~T[12:00:01], validation: :time, kind: :greater_than]}
               ]
             } = validate_time(cs, :start_date, greater_than: ~T[12:00:01])
    end

    test "validates greater than or equal to", %{changeset: cs} do
      assert %Changeset{valid?: true} =
               validate_time(cs, :start_date, greater_than_or_equal_to: ~T[11:59:59])

      assert %Changeset{valid?: true} =
               validate_time(cs, :start_date, greater_than_or_equal_to: ~T[12:00:00])

      assert %Changeset{
               valid?: false,
               errors: [
                 start_date:
                   {"must be at or after %{time}",
                    [time: ~T[12:00:01], validation: :time, kind: :greater_than_or_equal_to]}
               ]
             } = validate_time(cs, :start_date, greater_than_or_equal_to: ~T[12:00:01])
    end

    test "validates equal to", %{changeset: cs} do
      assert %Changeset{
               valid?: false,
               errors: [
                 start_date:
                   {"must be at %{time}",
                    [time: ~T[11:59:59], validation: :time, kind: :equal_to]}
               ]
             } = validate_time(cs, :start_date, equal_to: ~T[11:59:59])

      assert %Changeset{valid?: true} = validate_time(cs, :start_date, equal_to: ~T[12:00:00])

      assert %Changeset{
               valid?: false,
               errors: [
                 start_date:
                   {"must be at %{time}",
                    [time: ~T[12:00:01], validation: :time, kind: :equal_to]}
               ]
             } = validate_time(cs, :start_date, equal_to: ~T[12:00:01])
    end

    test "validates not equal to", %{changeset: cs} do
      assert %Changeset{valid?: true} = validate_time(cs, :start_date, not_equal_to: ~T[11:59:59])

      assert %Changeset{
               valid?: false,
               errors: [
                 start_date:
                   {"cannot be at %{time}",
                    [time: ~T[12:00:00], validation: :time, kind: :not_equal_to]}
               ]
             } = validate_time(cs, :start_date, not_equal_to: ~T[12:00:00])

      assert %Changeset{valid?: true} = validate_time(cs, :start_date, not_equal_to: ~T[12:00:01])
    end

    test "skips validating nil", %{changeset: cs} do
      assert %Changeset{valid?: true} = validate_time(cs, :start_date, equal_to: nil)
    end
  end

  describe "validate_date_time/4" do
    setup do
      [
        changeset: changeset(%{start_date: ~U[2020-01-01 12:00:00Z]})
      ]
    end

    test "validates less than", %{changeset: cs} do
      assert %Changeset{valid?: true} =
               validate_date_time(cs, :start_date, less_than: ~N[2020-01-01 12:00:01])

      assert %Changeset{
               valid?: false,
               errors: [
                 start_date:
                   {"must be before %{time}",
                    [time: ~N[2020-01-01 12:00:00], validation: :date_time, kind: :less_than]}
               ]
             } = validate_date_time(cs, :start_date, less_than: ~N[2020-01-01 12:00:00])

      assert %Changeset{
               valid?: false,
               errors: [
                 start_date:
                   {"must be before %{time}",
                    [time: ~N[2020-01-01 11:59:59], validation: :date_time, kind: :less_than]}
               ]
             } = validate_date_time(cs, :start_date, less_than: ~N[2020-01-01 11:59:59])
    end

    test "validates less than or equal to", %{changeset: cs} do
      assert %Changeset{valid?: true} =
               validate_date_time(cs, :start_date, less_than_or_equal_to: ~N[2020-01-01 12:00:01])

      assert %Changeset{valid?: true} =
               validate_date_time(cs, :start_date, less_than_or_equal_to: ~N[2020-01-01 12:00:00])

      assert %Changeset{
               valid?: false,
               errors: [
                 start_date:
                   {"must be at or before %{time}",
                    [
                      time: ~N[2020-01-01 11:59:59],
                      validation: :date_time,
                      kind: :less_than_or_equal_to
                    ]}
               ]
             } =
               validate_date_time(cs, :start_date, less_than_or_equal_to: ~N[2020-01-01 11:59:59])
    end

    test "validates greater than", %{changeset: cs} do
      assert %Changeset{valid?: true} =
               validate_date_time(cs, :start_date, greater_than: ~N[2020-01-01 11:59:59])

      assert %Changeset{
               valid?: false,
               errors: [
                 start_date:
                   {"must be after %{time}",
                    [time: ~N[2020-01-01 12:00:00], validation: :date_time, kind: :greater_than]}
               ]
             } = validate_date_time(cs, :start_date, greater_than: ~N[2020-01-01 12:00:00])

      assert %Changeset{
               valid?: false,
               errors: [
                 start_date:
                   {"must be after %{time}",
                    [time: ~N[2020-01-01 12:00:01], validation: :date_time, kind: :greater_than]}
               ]
             } = validate_date_time(cs, :start_date, greater_than: ~N[2020-01-01 12:00:01])
    end

    test "validates greater than or equal to", %{changeset: cs} do
      assert %Changeset{valid?: true} =
               validate_date_time(cs, :start_date,
                 greater_than_or_equal_to: ~N[2020-01-01 11:59:59]
               )

      assert %Changeset{valid?: true} =
               validate_date_time(cs, :start_date,
                 greater_than_or_equal_to: ~N[2020-01-01 12:00:00]
               )

      assert %Changeset{
               valid?: false,
               errors: [
                 start_date:
                   {"must be at or after %{time}",
                    [
                      time: ~N[2020-01-01 12:00:01],
                      validation: :date_time,
                      kind: :greater_than_or_equal_to
                    ]}
               ]
             } =
               validate_date_time(cs, :start_date,
                 greater_than_or_equal_to: ~N[2020-01-01 12:00:01]
               )
    end

    test "validates equal to", %{changeset: cs} do
      assert %Changeset{
               valid?: false,
               errors: [
                 start_date:
                   {"must be at %{time}",
                    [time: ~N[2020-01-01 11:59:59], validation: :date_time, kind: :equal_to]}
               ]
             } = validate_date_time(cs, :start_date, equal_to: ~N[2020-01-01 11:59:59])

      assert %Changeset{valid?: true} =
               validate_date_time(cs, :start_date, equal_to: ~N[2020-01-01 12:00:00])

      assert %Changeset{
               valid?: false,
               errors: [
                 start_date:
                   {"must be at %{time}",
                    [time: ~N[2020-01-01 12:00:01], validation: :date_time, kind: :equal_to]}
               ]
             } = validate_date_time(cs, :start_date, equal_to: ~N[2020-01-01 12:00:01])
    end

    test "validates not equal to", %{changeset: cs} do
      assert %Changeset{valid?: true} =
               validate_date_time(cs, :start_date, not_equal_to: ~U[2020-01-01 11:59:59Z])

      assert %Changeset{
               valid?: false,
               errors: [
                 start_date:
                   {"cannot be at %{time}",
                    [time: ~U[2020-01-01 12:00:00Z], validation: :date_time, kind: :not_equal_to]}
               ]
             } = validate_date_time(cs, :start_date, not_equal_to: ~U[2020-01-01 12:00:00Z])

      assert %Changeset{valid?: true} =
               validate_date_time(cs, :start_date, not_equal_to: ~U[2020-01-01 12:00:01Z])
    end

    test "skips validating nil", %{changeset: cs} do
      assert %Changeset{valid?: true} = validate_date_time(cs, :start_date, equal_to: nil)
    end
  end

  @phone_number_attrs %ExPhoneNumber.Model.PhoneNumber{
    country_code: nil,
    country_code_source: nil,
    extension: nil,
    italian_leading_zero: nil,
    national_number: nil,
    number_of_leading_zeros: nil,
    preferred_domestic_carrier_code: nil,
    raw_input: nil
  }

  describe "validate_phone_number/2" do
    test "fails when phone_number is invalid" do
      change(%Coupon{},
        phone_number: %{@phone_number_attrs | country_code: 1, national_number: 000_000_000}
      )
      |> validate_phone_number(:phone_number)
      |> assert_phone_error()

      change(%Coupon{},
        phone_number: %{@phone_number_attrs | country_code: 1, national_number: 829_304}
      )
      |> validate_phone_number(:phone_number)
      |> assert_phone_error()

      change(%Coupon{},
        phone_number: %{@phone_number_attrs | country_code: 9999, national_number: 829_304_0011}
      )
      |> validate_phone_number(:phone_number)
      |> assert_phone_error()

      change(%Coupon{},
        phone_number: %{@phone_number_attrs | country_code: nil, national_number: 829_304_0011}
      )
      |> validate_phone_number(:phone_number)
      |> assert_phone_error()
    end

    test "succeeds when phone_number is valid" do
      changeset =
        change(%Coupon{},
          phone_number: %{@phone_number_attrs | country_code: 1, national_number: 201_639_4134}
        )
        |> validate_phone_number(:phone_number)

      assert changeset.valid?

      changeset =
        change(%Coupon{},
          phone_number: %{@phone_number_attrs | country_code: 33, national_number: 735_558_583}
        )
        |> validate_phone_number(:phone_number)

      assert changeset.valid?

      changeset =
        change(%Coupon{},
          phone_number: %{@phone_number_attrs | country_code: 91, national_number: 936_778_8755}
        )
        |> validate_phone_number(:phone_number)

      assert changeset.valid?
    end
  end

  defp assert_phone_error(changeset) do
    assert {"The string supplied did not seem to be a valid phone number",
            [validation: :phone_number]} = changeset.errors[:phone_number]
  end
end
