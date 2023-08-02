defmodule FraytElixirWeb.API.Internal.AgreementDocumentViewTest do
  use FraytElixirWeb.ConnCase, async: true
  alias FraytElixirWeb.API.Internal.AgreementDocumentView
  alias FraytElixir.Accounts.AgreementDocument
  alias FraytElixirWeb.Router.Helpers, as: Routes
  import FraytElixir.Factory

  describe "render agreement_document" do
    test "renders agreement_document" do
      %AgreementDocument{
        id: id,
        title: title,
        type: type
      } = document = insert(:agreement_document, type: :eula)

      rendered_doc =
        AgreementDocumentView.render("agreement_document.json", %{agreement_document: document})

      url = Routes.agreement_document_url(FraytElixirWeb.Endpoint, :show, id)

      assert %{
               id: ^id,
               type: ^type,
               title: ^title,
               url: ^url,
               support_documents: []
             } = rendered_doc
    end

    test "render agreement_document with supporting docs" do
      %AgreementDocument{
        id: id,
        support_documents: [
          %AgreementDocument{
            id: supporting_id
          }
        ]
      } =
        document =
        insert(:agreement_document,
          type: :eula,
          support_documents: [build(:agreement_document, type: :delivery_agreement)]
        )

      rendered_doc =
        AgreementDocumentView.render("agreement_document.json", %{agreement_document: document})

      assert %{
               id: ^id,
               support_documents: [
                 %{
                   id: ^supporting_id
                 }
               ]
             } = rendered_doc
    end
  end

  describe "index" do
    test "renders list of documents" do
      %{id: eula_id} = eula = insert(:agreement_document, type: :eula)
      %{id: delivery_id} = delivery = insert(:agreement_document, type: :delivery_agreement)
      documents = [eula, delivery]

      rendered_docs =
        AgreementDocumentView.render("index.json", %{agreement_documents: documents})

      assert %{
               agreement_documents: [
                 %{id: ^eula_id},
                 %{id: ^delivery_id}
               ]
             } = rendered_docs
    end
  end
end
