defmodule FraytElixir.Webhooks.WebhookRequest do
  use FraytElixir.Schema

  alias FraytElixir.Accounts.Company
  alias FraytElixir.Webhooks.{WebhookRequestStateEnum, WebhookRequestTypeEnum}

  schema "webhook_requests" do
    field :payload, :map
    field :webhook_url, :string
    field :response, :string
    field :state, WebhookRequestStateEnum
    field :webhook_type, WebhookRequestTypeEnum
    field :record_id, :binary_id
    field :completed_at, :utc_datetime_usec
    field :sent_at, :utc_datetime_usec

    belongs_to :company, Company

    timestamps()
  end

  @required ~w(payload state company_id webhook_url webhook_type record_id)a
  @optional ~w(response completed_at sent_at)a

  def changeset(request, attrs) do
    request
    |> cast(attrs, @optional ++ @required)
    |> validate_required(@required)
  end
end
