defmodule FraytElixir.Contracts.Contract do
  use FraytElixir.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias FraytElixir.Accounts.Company
  alias FraytElixir.CustomContracts
  alias FraytElixir.Shipment.MatchState

  alias FraytElixir.Contracts.{
    ActiveMatchFactor,
    CancellationPayRule,
    CancellationCode,
    MarketConfig
  }

  alias FraytElixir.SLAs.ContractSLA
  alias FraytElixir.ChangesetHelpers

  schema "contracts" do
    field :name, :string
    field :contract_key, :string
    field :pricing_contract, CustomContracts.Type, default: :default
    field :disabled, :boolean, default: false

    field :allowed_cancellation_states, {:array, MatchState.Type},
      default: MatchState.restricted_cancelable_range()

    field :active_matches, :integer
    field :active_match_factor, ActiveMatchFactor.Type, default: :delivery_duration
    field :active_match_duration, :integer
    field :enable_cancellation_code, :boolean, virtual: true, default: false

    belongs_to :company, Company

    embeds_many :cancellation_pay_rules, CancellationPayRule, on_replace: :delete

    has_many :slas, ContractSLA, on_replace: :delete
    has_many :cancellation_codes, CancellationCode, on_replace: :delete

    has_many :market_configs, MarketConfig, on_replace: :delete

    timestamps()
  end

  def filter_by_company(query, nil), do: query

  def filter_by_company(query, company_id),
    do: from(c in query, where: ^company_id == c.company_id)

  def filter_by_query(query, nil), do: query

  def filter_by_query(query, search),
    do:
      from(c in query,
        where: ilike(c.name, ^"%#{search}%") or ilike(c.contract_key, ^"%#{search}%")
      )

  @doc false
  def changeset(contract, attrs) do
    contract
    |> cast(attrs, [
      :name,
      :contract_key,
      :pricing_contract,
      :company_id,
      :disabled,
      :enable_cancellation_code
    ])
    |> validate_required([:name, :contract_key, :pricing_contract, :company_id, :disabled])
    |> validate_format(:contract_key, ~r/^[_a-z0-9]*$/,
      message: "can only contain lower case letters, numbers, and underscores"
    )
    |> unique_constraint(:contract_key_company_id,
      message: "is already in use for the selected company"
    )
  end

  def cancellation_changeset(contract, attrs) do
    contract
    |> cast_from_form(attrs, [:allowed_cancellation_states, :enable_cancellation_code])
    |> validate_required([:allowed_cancellation_states])
    |> validate_subset(:allowed_cancellation_states, MatchState.editable_range())
    |> cast_embed(:cancellation_pay_rules)
    |> cast_assoc(:cancellation_codes, with: &CancellationCode.changeset/2)
  end

  @allowed_delivery_rules_field ~w(active_matches active_match_factor active_match_duration)a
  def delivery_rules_changeset(contract, attrs) do
    contract
    |> cast(attrs, @allowed_delivery_rules_field)
    |> validate_number(:active_matches, greater_than: 0)
    |> validate_number(:active_match_duration, greater_than: 0)
    |> validate_required_when(:active_match_duration, [
      {:active_match_factor, :equal_to, :fixed_duration}
    ])
  end

  def contract_sla_changeset(contract, attrs) do
    contract
    |> changeset(attrs)
    |> cast_assoc(:slas, with: &ContractSLA.changeset/2)
  end

  def contract_market_multiplier_changeset(contract, attrs) do
    contract
    |> ChangesetHelpers.cast_from_form(attrs, [])
    |> cast_assoc(:market_configs, with: &MarketConfig.changeset/2)
  end
end
