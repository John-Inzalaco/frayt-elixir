defmodule FraytElixir.SLAs.ContractSLA do
  use FraytElixir.Schema
  import Ecto.Changeset
  alias FraytElixir.Equations
  alias FraytElixir.Contracts.Contract
  alias FraytElixir.SLAs.{SLAType, SLADurationType}

  schema "contract_slas" do
    field :type, SLAType.Type
    field :duration, :string
    field :min_duration, :string
    field :time, :time
    field :duration_type, SLADurationType.Type, default: nil

    belongs_to :contract, Contract

    timestamps()
  end

  @required [:type]
  @optional [:time, :duration, :duration_type, :min_duration]

  @durations_var_defs %{
    "stop_delivery_time" => "minutes",
    "vehicle_load_time" => "minutes",
    "travel_duration" => "minutes",
    "market_pickup_sla_modifier" => "minutes",
    "total_distance" => "miles",
    "stop_count" => "integer"
  }

  @durations_vars Map.keys(@durations_var_defs)

  def duration_vars, do: @durations_vars
  def duration_var_defs, do: @durations_var_defs

  @doc false
  def changeset(contract_sla, attrs \\ %{}) do
    contract_sla
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_required_when(:duration, [{:duration_type, :equal_to, nil}])
    |> validate_required_when(:time, [{:duration_type, :not_equal_to, nil}])
    |> validate_required_when(:min_duration, [{:duration_type, :not_equal_to, nil}])
    |> Equations.validate_equation(:duration, @durations_vars)
    |> Equations.validate_equation(:min_duration, @durations_vars)
    |> unique_constraint(:contract_sla_type, message: "Only one SLA type per contract is allowed")
  end
end
