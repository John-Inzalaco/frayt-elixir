defmodule FraytElixirWeb.API.Internal.AgreementDocumentView do
  use FraytElixirWeb, :view
  alias FraytElixirWeb.API.Internal.AgreementDocumentView
  import FraytElixirWeb.AgreementDocumentView, only: [agreement_document_url: 1]

  def render("index.json", %{agreement_documents: documents}),
    do: %{
      agreement_documents:
        render_many(documents, AgreementDocumentView, "agreement_document.json")
    }

  def render("agreement_document.json", %{agreement_document: document}) do
    %{
      id: document.id,
      title: document.title,
      type: document.type,
      url: agreement_document_url(document.id),
      support_documents:
        case document.support_documents do
          documents when is_list(documents) ->
            render_many(documents, AgreementDocumentView, "agreement_document.json")

          _ ->
            []
        end
    }
  end
end
