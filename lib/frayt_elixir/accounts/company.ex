defmodule FraytElixir.Accounts.Company do
  use FraytElixir.Schema
  alias FraytElixir.Accounts.{AdminUser, ApiAccount, Location, Shipper, APIVersion}
  alias FraytElixir.Contracts.Contract
  alias FraytElixir.Webhooks.WebhookRequest
  alias FraytElixir.Integrations.IntegrationTypeEnum
  import Ecto.Query, only: [from: 2]
  import FraytElixir.Guards
  import FraytElixir.Sanitizers
  # time in milliseconds
  @auto_cancel_time 20 * 60 * 1000

  schema "companies" do
    field :name, :string
    field :account_billing_enabled, :boolean, default: false
    field :invoice_period, :integer
    field :email, :string
    field :match_count, :integer, default: 0
    field :shipper_count, :integer, default: 0
    field :location_count, :integer, default: 0
    field :old_company_id, :string
    field :webhook_url, :string
    field :autoselect_vehicle_class, :boolean, default: false
    field :origin_photo_required, :boolean
    field :destination_photo_required, :boolean
    field :is_enterprise, :boolean, default: false
    field :auto_cancel, :boolean, default: false
    field :auto_cancel_time, :integer, default: @auto_cancel_time
    field :auto_cancel_on_driver_cancel, :boolean, default: false
    field :auto_cancel_on_driver_cancel_time_after_acceptance, :integer, default: 0
    field :auto_incentivize_driver, :boolean, default: false
    field :page_count, :integer, virtual: true
    field :revenue, :integer, default: 0
    field :signature_required, :boolean, default: true
    field :integration, IntegrationTypeEnum, default: nil
    field :integration_id, :string
    field :api_key, :string

    has_many :contracts, Contract
    has_many :webhook_requests, WebhookRequest
    has_many :locations, Location
    has_one :api_account, ApiAccount
    belongs_to :sales_rep, AdminUser
    belongs_to :default_contract, Contract

    embeds_one :webhook_config, WebhookConfig, primary_key: false, on_replace: :update do
      field :auth_token, :string
      field :auth_header, :string
      field :api_version, APIVersion.Type, default: :"2.1"
      field :client_id, :string
      field :secret, :string
    end

    timestamps()
  end

  @allowed_attrs ~w(
    name account_billing_enabled invoice_period email sales_rep_id webhook_url autoselect_vehicle_class
    is_enterprise auto_cancel auto_cancel_time auto_incentivize_driver auto_cancel_on_driver_cancel
    auto_cancel_on_driver_cancel_time_after_acceptance origin_photo_required destination_photo_required
    signature_required default_contract_id integration integration_id api_key
  )a

  @allowed_webhook_attrs ~w(auth_token auth_header api_version client_id secret)a

  @doc false
  def changeset(company, attrs) do
    company
    |> cast(attrs, @allowed_attrs)
    |> cast_embed(:webhook_config, with: &webhook_config_changeset/2)
    |> trim_string(:webhook_url)
    |> validate_required([:name])
    |> validate_required_when(:invoice_period, [{:account_billing_enabled, :equal_to, true}])
  end

  def webhook_config_changeset(schema, attrs) do
    schema
    |> cast(attrs, @allowed_webhook_attrs)
    |> trim_string(:auth_header)
    |> trim_string(:auth_token)
    |> validate_required([:api_version])
    |> validate_required_when(:auth_header, [{:auth_token, :not_equal_to, nil}])
    |> validate_required_when(:auth_token, [{:auth_header, :not_equal_to, nil}])
  end

  def create_changeset(company, attrs) do
    company
    |> changeset(attrs)
    |> cast_assoc(:locations)
  end

  def update_changeset(company, attrs) do
    company
    |> changeset(attrs)
    |> cast_assoc(:locations, with: &Location.company_changeset/2)
  end

  def filter_by_query(query, search_query) when is_empty(search_query), do: query

  def filter_by_query(query, search_query),
    do: from(c in query, where: ilike(c.name, ^"%#{search_query}%"))

  def filter_by_sales_rep(query, nil), do: query

  def filter_by_sales_rep(query, sales_rep_id),
    do: from(c in query, where: c.sales_rep_id == ^sales_rep_id)

  def filter_by_enterprise_only(query, false), do: query

  def filter_by_enterprise_only(query, true),
    do: from(c in query, where: c.is_enterprise)

  def location_revenue_query do
    shipper_revenue_query =
      from(shipper in Shipper,
        left_join: match in assoc(shipper, :matches),
        group_by: shipper.id,
        select: %{
          shipper
          | revenue:
              sum(
                fragment(
                  "CASE WHEN ? THEN ? WHEN ? THEN ? ELSE 0 END",
                  match.state in ["canceled", "admin_canceled"],
                  match.cancel_charge,
                  match.state in ["completed", "charged"],
                  match.amount_charged
                )
              )
        },
        select_merge: %{
          match_count: count(fragment("CASE WHEN ? THEN ? END", match.state != "pending", match))
        }
      )

    from(location in Location,
      left_join: shipper in subquery(shipper_revenue_query),
      on: shipper.location_id == location.id,
      group_by: location.id,
      select: %{
        location
        | revenue: fragment("cast(coalesce(?, 0) as bigint)", sum(shipper.revenue))
      },
      select_merge: %{
        shipper_count:
          count(fragment("CASE WHEN ? THEN ? END", shipper.state == :approved, shipper)),
        match_count: sum(shipper.match_count)
      }
    )
  end
end
