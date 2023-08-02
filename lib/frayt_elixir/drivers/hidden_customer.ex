defmodule FraytElixir.Drivers.HiddenCustomer do
  use FraytElixir.Schema

  alias FraytElixir.Accounts.{Shipper, Company}
  alias FraytElixir.Drivers.Driver

  schema "hidden_customers" do
    field :reason, :string

    belongs_to :shipper, Shipper
    belongs_to :company, Company
    belongs_to :driver, Driver

    timestamps()
  end

  @doc false
  def changeset(hidden_customer, attrs) do
    hidden_customer
    |> cast(attrs, [:reason, :shipper_id, :company_id, :driver_id])
    |> validate_required(:driver_id)
    |> validate_one_of_present([:shipper_id, :company_id])
    |> foreign_key_constraint(:shipper_id)
    |> foreign_key_constraint(:company_id)
    |> foreign_key_constraint(:driver_id)
    |> unique_constraint(:driver_id_shipper_id, message: "has already been blocked")
    |> unique_constraint(:driver_id_company_id, message: "has already been blocked")
  end
end
