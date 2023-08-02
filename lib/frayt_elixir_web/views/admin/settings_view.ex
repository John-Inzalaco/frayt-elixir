defmodule FraytElixirWeb.Admin.SettingsView do
  use FraytElixirWeb, :view
  import FraytElixirWeb.DisplayFunctions

  alias FraytElixir.Accounts.{
    DocumentType,
    DocumentState,
    UserType,
    AgreementDocument,
    AdminRole
  }

  alias FraytElixirWeb.DataTable.Helpers, as: Table

  def agreement_document_url(id) do
    FraytElixirWeb.Router.Helpers.agreement_document_url(FraytElixirWeb.Endpoint, :show, id)
  end

  def save_agreement_label(id, state) when is_binary(state),
    do: save_agreement_label(id, String.to_existing_atom(state))

  def save_agreement_label(id, state) do
    cond do
      state == :published -> "Publish Agreement"
      id == "new" -> "Create Draft"
      true -> "Update Draft"
    end
  end
end
