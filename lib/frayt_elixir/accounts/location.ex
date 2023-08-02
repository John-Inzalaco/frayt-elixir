defmodule FraytElixir.Accounts.Location do
  use FraytElixir.Schema
  import FraytElixir.Guards
  import Ecto.Query, only: [from: 2]
  alias FraytElixir.Accounts.{AdminUser, Company, Schedule, Shipper}
  alias FraytElixir.Shipment.Address

  schema "locations" do
    field :email, :string
    field :invoice_period, :integer
    field :location, :string
    field :store_number, :string
    field :revenue, :integer, virtual: true
    field :shipper_count, :integer, virtual: true, default: 0
    field :match_count, :integer, virtual: true, default: 0
    field :old_location_id, :string
    belongs_to :company, Company
    belongs_to :address, Address
    belongs_to :sales_rep, AdminUser
    has_many :shippers, Shipper
    has_one :schedule, Schedule

    timestamps()
  end

  def filter_by_company(query, company_id) when is_empty(company_id), do: query

  def filter_by_company(query, company_id),
    do: from(l in query, where: l.company_id == ^company_id)

  def filter_by_query(query, search_query) when is_empty(search_query), do: query

  def filter_by_query(query, search_query),
    do:
      from(l in query,
        left_join: lsr in assoc(l, :sales_rep),
        left_join: lu in assoc(lsr, :user),
        left_join: la in assoc(l, :address),
        where:
          ilike(l.store_number, ^"%#{search_query}%") or ilike(l.email, ^"%#{search_query}%") or
            ilike(l.location, ^"%#{search_query}%") or ilike(lsr.name, ^"%#{search_query}%") or
            ilike(la.formatted_address, ^"%#{search_query}%") or
            ilike(lu.email, ^"%#{search_query}%")
      )

  def calculate_revenue(id) do
    from(l in Company.location_revenue_query(),
      where: l.id == ^id
    )
    |> FraytElixir.Repo.one()
    |> Map.get(:revenue)
  end

  @doc false
  def changeset(location, attrs) do
    location
    |> cast(attrs, [
      :location,
      :store_number,
      :email,
      :company_id,
      :address_id,
      :invoice_period,
      :sales_rep_id
    ])
    |> foreign_key_constraint(:company_id)
    |> foreign_key_constraint(:address_id)
    |> validate_required([:location, :company_id, :address_id])
    |> cast_assoc(:shippers)
  end

  def company_changeset(location, attrs) do
    location
    |> cast(attrs, [
      :company_id,
      :sales_rep_id,
      :invoice_period
    ])
    |> foreign_key_constraint(:company_id)
    |> validate_required([:company_id])
    |> cast_assoc(:shippers, with: &Shipper.location_changeset/2)
  end

  def validate_company_location(location, attrs) do
    location
    |> cast(attrs, [
      :location,
      :store_number,
      :email,
      :company_id,
      :address_id,
      :invoice_period,
      :sales_rep_id
    ])
    |> foreign_key_constraint(:company_id)
    |> foreign_key_constraint(:address_id)
    |> validate_required([:location])
  end
end
