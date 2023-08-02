defmodule FraytElixir.Hubspot.Account do
  use Ecto.Schema
  import Ecto.Changeset

  @allowed_hubspot_ids Application.compile_env(:frayt_elixir, :allowed_hubspot_accounts)

  schema "hubspot_accounts" do
    field :hubspot_id, :integer
    field :domain, :string
    field :access_token, :string
    field :refresh_token, :string
    field :expires_at, :utc_datetime

    timestamps()
  end

  @doc false
  def changeset(integrations, attrs) do
    integrations
    |> cast(attrs, [:refresh_token, :access_token, :expires_at, :hubspot_id, :domain])
    |> validate_required([:refresh_token, :access_token, :expires_at, :hubspot_id, :domain])
    |> validate_allowed_account()
  end

  if is_list(@allowed_hubspot_ids) do
    defp validate_allowed_account(changeset) do
      validate_change(changeset, :hubspot_id, :allowed_account, fn _field, hubspot_id ->
        case hubspot_id in @allowed_hubspot_ids do
          true -> []
          _ -> [hubspot_id: {"is not an allowed hubspot account", [validation: :allowed_account]}]
        end
      end)
    end
  else
    defp validate_allowed_account(changeset), do: changeset
  end
end
