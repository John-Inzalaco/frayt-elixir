defmodule FraytElixirWeb.API.Internal.AgreementDocumentControllerTest do
  use FraytElixirWeb.ConnCase
  import FraytElixir.Factory

  describe "index" do
    test "lists all pending agreements for driver", %{conn: conn} do
      driver = insert(:driver)
      conn = add_token_for_driver(conn, driver)
      %{id: doc_id} = insert(:agreement_document, user_types: [:driver])

      insert(:agreement_document,
        user_types: [:driver],
        updated_at: ~N[2020-01-01 00:00:00],
        agreements: [
          build(:user_agreement,
            document: nil,
            user: driver.user,
            updated_at: ~N[2021-02-01 00:00:00]
          )
        ]
      )

      conn = get(conn, Routes.api_v2_agreement_document_path(conn, :index, ".1", "driver"))

      assert %{
               "agreement_documents" => [
                 %{
                   "id" => ^doc_id
                 }
               ]
             } = json_response(conn, 200)
    end

    test "lists pending agreements for shipper", %{conn: conn} do
      shipper = insert(:shipper)
      conn = add_token_for_shipper(conn, shipper)
      %{id: doc_id} = insert(:agreement_document, user_types: [:shipper])

      insert(:agreement_document,
        user_types: [:shipper],
        updated_at: ~N[2020-01-01 00:00:00],
        agreements: [
          build(:user_agreement,
            document: nil,
            user: shipper.user,
            updated_at: ~N[2021-02-01 00:00:00]
          )
        ]
      )

      conn = get(conn, Routes.api_v2_agreement_document_path(conn, :index, ".1", "shipper"))

      assert %{
               "agreement_documents" => [
                 %{
                   "id" => ^doc_id
                 }
               ]
             } = json_response(conn, 200)
    end

    test "lists pending agreements for unauthorized user", %{conn: conn} do
      %{id: doc_id} = insert(:agreement_document, user_types: [:shipper])
      insert(:agreement_document, user_types: [:driver])
      conn = get(conn, Routes.api_v2_agreement_document_path(conn, :index, ".1", "shipper"))

      assert %{
               "agreement_documents" => [
                 %{
                   "id" => ^doc_id
                 }
               ]
             } = json_response(conn, 200)
    end
  end

  describe "create" do
    setup :login_as_shipper

    test "creates user agreements", %{conn: conn} do
      %{id: doc_id} =
        insert(:agreement_document, user_types: [:shipper], updated_at: "2020-01-01T00:00:00")

      conn =
        post(
          conn,
          Routes.api_v2_agreement_document_path(conn, :create, ".1", "shipper"),
          %{
            agreements: [
              %{document_id: doc_id, agreed: true, updated_at: "2021-01-01T00:00:00"}
            ]
          }
        )

      assert %{
               "agreement_documents" => []
             } = json_response(conn, 200)
    end

    test "returns error when rejected", %{conn: conn} do
      %{id: doc_id} = insert(:agreement_document, user_types: [:shipper])

      conn =
        post(
          conn,
          Routes.api_v2_agreement_document_path(conn, :create, ".1", "shipper"),
          %{
            agreements: [
              %{document_id: doc_id, agreed: false, updated_at: "2020-01-01T00:00:00"}
            ]
          }
        )

      assert %{
               "message" => "Agreed you must accept agreements to continue"
             } = json_response(conn, 422)
    end

    test "returns error when no agreements", %{conn: conn} do
      insert(:agreement_document, user_types: [:shipper])

      conn =
        post(
          conn,
          Routes.api_v2_agreement_document_path(conn, :create, ".1", "shipper", %{})
        )

      assert %{"message" => "Agreements can't be blank"} = json_response(conn, 422)
    end

    test "returns error when not logged in", %{conn: conn} do
      insert(:agreement_document, user_types: [:shipper])

      conn =
        conn
        |> logout()
        |> post(Routes.api_v2_agreement_document_path(conn, :create, ".1", "shipper", %{}))

      assert json_response(conn, 401)
    end
  end
end
