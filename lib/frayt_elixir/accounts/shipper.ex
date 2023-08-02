defmodule FraytElixir.Accounts.Shipper do
  use FraytElixir.Schema
  import Ecto.Query
  import FraytElixir.Sanitizers
  import FraytElixir.Guards

  alias FraytElixir.Accounts.{AdminUser, Location, User, ShipperRole, ShipperState}
  alias FraytElixir.Payments.CreditCard
  alias FraytElixir.Shipment.{Match, Address}

  import FraytElixir.PaginationQueryHelpers, only: [set_assoc: 3]

  schema "shippers" do
    field :first_name, :string
    field :last_name, :string
    field :agreement, :boolean, default: false
    field :company, :string
    field :phone, :string
    field :referrer, :string
    field :commercial, :boolean
    field :hubspot_id, :string
    field :texting, :boolean
    field :state, ShipperState.Type, default: :pending_approval
    field :stripe_customer_id, :string
    field :one_signal_id, :string
    field :revenue, :integer, virtual: true
    field :match_count, :integer, virtual: true, default: 0
    field :role, ShipperRole.Type, default: :member

    belongs_to :user, User, on_replace: :update
    belongs_to :location, Location
    belongs_to :sales_rep, AdminUser
    belongs_to :address, Address, on_replace: :update

    has_one :credit_card, CreditCard
    has_many :matches, Match

    timestamps()
  end

  def tag_new_shippers(query) do
    from(shipper in query,
      left_join: match in assoc(shipper, :matches),
      on: match.shipper_id == shipper.id,
      where: match.state == "charged",
      select: %{shipper | new: count(match) == 0}
    )
  end

  def new_shipper?(query, id) do
    closed_match_query =
      from(match in Match,
        where: match.state == "charged"
      )

    if id do
      from(shipper in query,
        left_join: match in subquery(closed_match_query),
        on: match.shipper_id == shipper.id,
        where: shipper.id == ^id,
        select: count(match) == 0
      )
    else
      from(shipper in query, where: false)
    end
  end

  def new_query,
    do: from(s in __MODULE__, as: :shipper)

  def filter_by_query(query, search_query) when is_empty(search_query), do: query

  def filter_by_query(query, search_query),
    do:
      query
      |> join_user()
      |> where(
        [user: u, shipper: s],
        ilike(fragment("CONCAT(?, ' ', ?)", s.first_name, s.last_name), ^"%#{search_query}%") or
          ilike(u.email, ^"%#{search_query}%")
      )

  def filter_by_location(query, nil),
    do: from(s in query, where: false)

  def filter_by_location(query, location_id),
    do: from(s in query, where: s.location_id == ^location_id)

  def filter_by_company(query, nil), do: query

  def filter_by_company(query, company_id),
    do:
      query
      |> join_location()
      |> where([location: l], l.company_id == ^company_id)

  def filter_by_role(query, nil), do: query

  def filter_by_role(query, roles) when is_list(roles),
    do: from(s in query, where: s.role in ^roles)

  def filter_by_role(query, role),
    do: from(s in query, where: s.role == ^role)

  def filter_by_sales_rep(query, nil), do: query

  def filter_by_sales_rep(query, sales_rep_id),
    do:
      query
      |> join_company()
      |> where(
        [company: c, shipper: s],
        (not is_nil(c.id) and ^sales_rep_id == c.sales_rep_id) or
          ^sales_rep_id == s.sales_rep_id
      )

  def filter_by_permissions(
        query,
        %__MODULE__{role: :company_admin, location: %{company_id: company_id}},
        location_id
      ) do
    query =
      if location_id,
        do: filter_by_location(query, location_id),
        else: query

    filter_by_company(query, company_id)
  end

  def filter_by_permissions(query, %__MODULE__{location_id: location_id}, _location_id),
    do:
      query
      |> filter_by_location(location_id)
      |> filter_by_role([:location_admin, :member])

  def filter_by_state(query, nil), do: query
  def filter_by_state(query, state), do: from(s in query, where: s.state == ^state)

  defp join_location(query), do: set_assoc(query, :location, from: :shipper)

  defp join_company(query),
    do:
      query
      |> join_location()
      |> set_assoc(:company, from: :location)

  defp join_user(query),
    do: set_assoc(query, :user, from: :shipper)

  @allowed_fields ~w(company agreement phone referrer commercial
  hubspot_id texting stripe_customer_id location_id first_name
  last_name one_signal_id sales_rep_id state role)a

  @doc false
  def changeset(shipper, attrs) do
    shipper
    |> cast(attrs, @allowed_fields)
    |> foreign_key_constraint(:location_id)
    |> strip_nondigits(:phone)
    |> validate_required([:first_name, :last_name, :phone, :agreement, :role])
  end

  def update_changeset(shipper, attrs) do
    shipper
    |> changeset(attrs)
    |> cast_assoc(:user,
      required: true,
      with: &FraytElixir.Accounts.User.update_changeset/2
    )
    |> cast_assoc(:address, required: true)
  end

  @allowed_account_shipper_fields ~w(first_name last_name phone state role location_id sales_rep_id)a

  def account_shipper_changeset(shipper, attrs, current_shipper) do
    shipper
    |> cast(attrs, @allowed_account_shipper_fields)
    |> cast_assoc(:user,
      required: true,
      with: &FraytElixir.Accounts.User.update_changeset/2
    )
    |> validate_required([:first_name, :last_name, :phone, :role, :location_id])
    |> validate_account_shipper(current_shipper)
  end

  def validate_account_shipper(changeset, current_shipper) do
    locations =
      case current_shipper do
        %{location: %{company: %{locations: [_ | _] = locations}}, role: :company_admin} ->
          Enum.map(locations, & &1.id)

        %{location_id: location_id} ->
          [location_id]
      end

    changeset = validate_inclusion(changeset, :location_id, locations)

    case current_shipper.role do
      :company_admin ->
        validate_inclusion(changeset, :role, [:location_admin, :member])

      :location_admin ->
        validate_inclusion(changeset, :role, [:member])

      :member ->
        add_error(changeset, :role, "cannot be edited by a member", validation: :account_shipper)
    end
  end

  def location_changeset(shipper, attrs) do
    shipper
    |> cast(attrs, [
      :location_id,
      :sales_rep_id
    ])
    |> foreign_key_constraint(:location_id)
  end

  def hubspot_changeset(shipper, attrs) do
    shipper
    |> cast(attrs, [:hubspot_id, :sales_rep_id])
  end

  def update_profile_changeset(shipper, attrs) do
    shipper
    |> cast(attrs, [:first_name, :last_name, :phone])
    |> cast_assoc(:address)
    |> strip_nondigits(:phone)
    |> validate_required([:first_name, :last_name, :phone])
  end

  def update_stripe_changeset(shipper, attrs) do
    shipper
    |> cast(attrs, [:stripe_customer_id])
    |> validate_required([:stripe_customer_id])
  end
end
