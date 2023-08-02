defmodule FraytElixir.Contracts.CancellationCode do
  use FraytElixir.Schema
  import Ecto.Changeset

  alias FraytElixir.Contracts.Contract

  schema "cancellation_codes" do
    field(:code, :string)
    field(:message, :string)

    belongs_to(:contract, Contract)

    timestamps()
  end

  def changeset(cancellation_code, attrs \\ %{}) do
    cancellation_code
    |> cast(attrs, [:code, :message])
  end
end
