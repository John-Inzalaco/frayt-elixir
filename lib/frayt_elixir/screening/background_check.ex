defmodule FraytElixir.Screenings.BackgroundCheck do
  use Ecto.Schema
  import Ecto.Changeset
  alias FraytElixir.Drivers.Driver
  alias FraytElixir.Screenings.ScreeningState

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "background_checks" do
    belongs_to :driver, Driver

    field :turn_id, :string
    field :turn_url, :string
    field :customer_id, :string
    field :transaction_id, :string
    field :amount_charged, :integer
    field :state, ScreeningState.Type, default: :pending
    field :turn_state, :string
    field :turn_consent_url, :string

    timestamps()
  end

  @allowed_fields ~w(driver_id customer_id transaction_id amount_charged state turn_id turn_url turn_state turn_consent_url)a

  @doc false
  def changeset(background_check, attrs) do
    background_check
    |> cast(attrs, @allowed_fields)
    |> validate_required([])
  end
end
