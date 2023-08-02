defmodule FraytElixir.Accounts.AgreementDocument do
  use FraytElixir.Schema
  import FraytElixir.Guards
  import Ecto.Query, only: [from: 2]

  alias FraytElixir.Accounts.{
    AgreementDocument,
    DocumentState,
    DocumentType,
    UserAgreement,
    UserType
  }

  alias FraytElixir.Type.HTML

  schema "agreement_documents" do
    field :title, :string
    field :content, HTML
    field :type, DocumentType.Type
    field :user_types, {:array, UserType.Type}
    field :state, DocumentState.Type, default: :draft

    belongs_to :parent_document, AgreementDocument, foreign_key: :parent_document_id
    has_many :support_documents, AgreementDocument, foreign_key: :parent_document_id
    has_many :agreements, UserAgreement, foreign_key: :document_id

    timestamps()
  end

  def filter_by_query(query, search_query) when is_empty(search_query), do: query

  def filter_by_query(query, search_query),
    do:
      from(ad in query,
        where: ilike(ad.type, ^"%#{search_query}%"),
        or_where: ilike(fragment("array_to_string(?, ',')", ad.user_types), ^"%#{search_query}%"),
        or_where: ilike(ad.title, ^"%#{search_query}%")
      )

  @doc false
  def changeset(agreement_documents, attrs) do
    agreement_documents
    |> cast_from_form(attrs, [:title, :content, :type, :parent_document_id, :state, :user_types])
    |> validate_required([:title, :content, :user_types, :type, :state])
    |> validate_required_when(:parent_document_id, [{:type, :not_equal_to, :eula}])
    |> validate_length(:user_types, min: 1)
  end
end
