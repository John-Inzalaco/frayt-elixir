defmodule FraytElixirWeb.ContactView do
  use FraytElixirWeb, :view
  import FraytElixirWeb.DisplayFunctions

  def render("contact.json", %{
        contact: %{
          id: id,
          name: name,
          email: email,
          phone_number: phone_number,
          notify: notify
        }
      }),
      do: %{
        id: id,
        name: name,
        email: email,
        notify: notify,
        phone_number: format_phone(phone_number)
      }
end
