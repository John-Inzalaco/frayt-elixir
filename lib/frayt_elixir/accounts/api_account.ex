defmodule FraytElixir.Accounts.ApiAccount do
  use FraytElixir.Schema
  alias FraytElixir.Accounts.Company

  schema "api_accounts" do
    field :client_id, :string
    field :secret, :string
    belongs_to :company, Company

    timestamps()
  end

  @doc false
  def new_account_changeset(api_account, company) do
    generate_client_and_secret_fn =
      Application.get_env(
        :frayt_elixir,
        :generate_client_and_secret,
        &generate_client_and_secret/1
      )

    api_account
    |> change
    |> put_assoc(:company, company)
    |> generate_client_and_secret_fn.()
    |> validate_required([:client_id, :secret, :company])
  end

  def generate_client_and_secret(%Ecto.Changeset{} = cset) do
    cset
    |> put_change(:client_id, Ecto.UUID.generate())
    |> put_change(:secret, Ecto.UUID.generate())
  end

  def changeset(api_account, attrs) do
    api_account
    |> cast(attrs, [:client_id, :secret])
  end
end
