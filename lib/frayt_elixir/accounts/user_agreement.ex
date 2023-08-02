defmodule FraytElixir.Accounts.UserAgreement do
  use FraytElixir.Schema
  use Waffle.Ecto.Schema
  import Ecto.Changeset
  alias FraytElixir.Photo
  alias FraytElixir.Accounts.{AgreementDocument, User}

  schema "user_agreements" do
    field :agreed, :boolean
    field :signature, Photo.Type
    belongs_to :user, User
    belongs_to :document, AgreementDocument

    timestamps()
  end

  @doc false
  def changeset(agreement, attrs) do
    agreement
    |> cast(attrs, [:document_id, :agreed, :updated_at, :user_id])
    |> cast_attachments(attrs, [:signature])
    |> validate_required([:document_id, :agreed, :updated_at])
    |> validate_agreement()
  end

  defp validate_agreement(changeset) do
    validate_change(changeset, :agreed, fn :agreed, agreed ->
      if agreed do
        []
      else
        [agreed: {"you must accept agreements to continue", [validation: :has_agreed]}]
      end
    end)
  end
end
