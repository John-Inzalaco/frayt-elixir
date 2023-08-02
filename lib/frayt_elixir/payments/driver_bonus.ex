defmodule FraytElixir.Payments.DriverBonus do
  use FraytElixir.Schema
  alias FraytElixir.Drivers.Driver
  alias FraytElixir.Payments.PaymentTransaction
  alias FraytElixir.Accounts.AdminUser

  schema "driver_bonuses" do
    field :notes, :string
    belongs_to :driver, Driver
    belongs_to :payment_transaction, PaymentTransaction
    belongs_to :created_by, AdminUser, foreign_key: :created_by_id

    timestamps()
  end

  @doc false
  def changeset(driver_bonus, attrs) do
    driver_bonus
    |> cast(attrs, [
      :notes,
      :driver_id,
      :payment_transaction_id,
      :created_by_id
    ])
    |> validate_required([:driver_id])
  end
end
