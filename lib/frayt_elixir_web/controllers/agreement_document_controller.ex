defmodule FraytElixirWeb.AgreementDocumentController do
  use FraytElixirWeb, :controller

  alias FraytElixir.Accounts

  action_fallback FraytElixirWeb.FallbackController

  def show(conn, %{"id" => id}) do
    case Accounts.get_agreement_document(id) do
      {:ok, %{state: :published} = document} ->
        render(conn, "agreement.html", agreement_document: document)

      {:ok, _} ->
        {:error, :not_found}

      error ->
        error
    end
  end
end
