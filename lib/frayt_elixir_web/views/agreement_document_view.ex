defmodule FraytElixirWeb.AgreementDocumentView do
  use FraytElixirWeb, :view
  alias FraytElixirWeb.Router.Helpers, as: Routes
  import FraytElixirWeb.DisplayFunctions

  def agreement_document_url(id) do
    Routes.agreement_document_url(FraytElixirWeb.Endpoint, :show, id)
  end
end
