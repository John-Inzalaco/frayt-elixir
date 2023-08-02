defmodule FraytElixirWeb.AgreementDocumentControllerTest do
  use FraytElixirWeb.ConnCase
  import FraytElixir.Factory

  describe "show" do
    setup [:login_as_shipper]

    test "returns html documents", %{conn: conn} do
      agreement = insert(:agreement_document)
      conn = get(conn, Routes.agreement_document_path(conn, :show, agreement.id))
      assert response = html_response(conn, 200)
      assert response =~ agreement.title
    end

    test "returns not found for drafts", %{conn: conn} do
      agreement = insert(:agreement_document, state: :draft)
      conn = get(conn, Routes.agreement_document_path(conn, :show, agreement.id))
      assert json_response(conn, 404)
    end
  end
end
