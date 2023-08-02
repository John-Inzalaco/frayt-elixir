defmodule FraytElixir.Shipment.ShipperMatchCoupon do
  use FraytElixir.Schema
  import Ecto.Query, only: [from: 2]

  alias FraytElixir.Accounts.Shipper
  alias FraytElixir.Shipment.{Match, Coupon}
  alias FraytElixir.Shipment
  alias FraytElixir.Repo

  schema "shipper_match_coupons" do
    belongs_to :shipper, Shipper
    belongs_to :match, Match
    belongs_to :coupon, Coupon

    timestamps()
  end

  def where_shipper_is(query, shipper_id) do
    from(smc in query,
      where: smc.shipper_id == type(^shipper_id, :binary_id)
    )
  end

  def where_coupon_is(query, coupon_id) do
    from(smc in query,
      where: smc.coupon_id == type(^coupon_id, :binary_id)
    )
  end

  def where_match_is(query, match_id) do
    from(smc in query,
      where: smc.match_id == type(^match_id, :binary_id)
    )
  end

  def where_match_is_not(query, nil), do: query

  def where_match_is_not(query, match_id) do
    from(smc in query,
      where: smc.match_id != type(^match_id, :binary_id)
    )
  end

  def where_match_state_is(query, state) do
    from(smc in query, join: m in "matches", on: m.id == smc.match_id, where: m.state == ^state)
  end

  def where_match_state_is_not(query, state) do
    from(smc in query,
      join: m in "matches",
      on: m.id == smc.match_id,
      where: m.state != ^state or is_nil(m.state)
    )
  end

  @doc false
  def changeset(shipper_match_coupon, attrs, %Match{} = match, coupon \\ nil) do
    changeset =
      shipper_match_coupon
      |> cast(attrs, [:shipper_id, :match_id, :coupon_id])

    coupon =
      case coupon do
        nil ->
          coupon_id = get_field(changeset, :coupon_id)
          if not is_nil(coupon_id), do: Repo.get(Coupon, coupon_id)

        _ ->
          coupon
      end

    changeset
    |> validate_required([:match_id])
    |> validate_required([:coupon_id], message: "code is invalid")
    |> validate_coupon_is_within_limit_for_shipper(coupon)
    |> validate_coupon_price_requirements(match, coupon)
    |> validate_coupon_is_not_expired(coupon)
  end

  defp validate_coupon_is_within_limit_for_shipper(changeset, coupon) do
    match_id = get_field(changeset, :match_id)
    shipper_id = get_field(changeset, :shipper_id)

    if coupon && shipper_id && not is_nil(coupon.use_limit) do
      query =
        __MODULE__
        |> where_match_is_not(match_id)
        |> where_shipper_is(shipper_id)
        |> where_coupon_is(coupon.id)
        |> where_match_state_is_not("pending")

      count = Repo.aggregate(query, :count)

      if count < coupon.use_limit do
        changeset
      else
        add_error(changeset, :coupon_id, "code has already been used")
      end
    else
      changeset
    end
  end

  defp validate_coupon_price_requirements(changeset, match, coupon) do
    if coupon && match do
      base_price = Shipment.get_match_fee_price(match, :base_fee, :shipper)

      cond do
        not is_nil(coupon.price_maximum) and base_price > coupon.price_maximum ->
          add_error(changeset, :coupon_id, "is invalid for orders above $%{max}",
            max: coupon.price_maximum / 100
          )

        not is_nil(coupon.price_minimum) and base_price < coupon.price_minimum ->
          add_error(changeset, :coupon_id, "is invalid for orders below $%{min}",
            min: coupon.price_minimum / 100
          )

        true ->
          changeset
      end
    else
      changeset
    end
  end

  defp validate_coupon_is_not_expired(changeset, coupon) do
    now = DateTime.utc_now()

    cond do
      is_nil(coupon) ->
        changeset

      coupon.start_date && DateTime.compare(now, coupon.start_date) == :lt ->
        add_error(changeset, :coupon_id, "is not active")

      coupon.end_date && DateTime.compare(now, coupon.end_date) == :gt ->
        add_error(changeset, :coupon_id, "is expired")

      true ->
        changeset
    end
  end
end
