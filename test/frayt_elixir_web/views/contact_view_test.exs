defmodule FraytElixirWeb.ContactViewTest do
  use FraytElixirWeb.ConnCase, async: true
  alias FraytElixirWeb.ContactView
  alias FraytElixir.Shipment.Contact

  import FraytElixir.Factory

  test "render contact" do
    %Contact{
      id: id,
      name: name,
      email: email,
      notify: notify
    } = contact = insert(:contact, phone_number: "+15134019301")

    assert %{
             id: ^id,
             name: ^name,
             email: ^email,
             phone_number: "+1 513-401-9301",
             notify: ^notify
           } = ContactView.render("contact.json", %{contact: contact})
  end
end
