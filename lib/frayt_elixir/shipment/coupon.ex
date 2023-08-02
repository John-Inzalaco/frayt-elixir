defmodule FraytElixir.Shipment.Coupon do
  use FraytElixir.Schema

  schema "coupons" do
    field :code, :string
    field :percentage, :integer
    field :start_date, :utc_datetime
    field :end_date, :utc_datetime
    field :use_limit, :integer
    field :price_minimum, :integer
    field :price_maximum, :integer
    field :discount_maximum, :integer
    field :old_coupon_id, :string

    timestamps()
  end

  def changeset(coupon, attrs) do
    coupon
    |> cast(attrs, [
      :code,
      :percentage,
      :discount_maximum,
      :start_date,
      :end_date,
      :use_limit,
      :price_minimum,
      :price_maximum
    ])
    |> validate_required([:code, :percentage])
    |> validate_start_before_end_date()
    |> validate_number(:use_limit, greater_than: 0)
    |> validate_number_by_field(:price_minimum, less_than_or_equal_to: :price_maximum)
  end

  def validate_start_before_end_date(changeset) do
    start_date = get_field(changeset, :start_date)
    end_date = get_field(changeset, :end_date)

    compare_dates(changeset, start_date, end_date)
  end

  defp compare_dates(changeset, start_date, end_date)
       when is_nil(start_date) or is_nil(end_date) do
    changeset
  end

  defp compare_dates(changeset, start_date, end_date) do
    case DateTime.compare(start_date, end_date) do
      :lt -> changeset
      _ -> add_error(changeset, :start_date, "must be earlier than end date")
    end
  end
end
