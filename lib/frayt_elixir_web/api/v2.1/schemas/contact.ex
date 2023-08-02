defmodule FraytElixirWeb.API.V2x1.Schemas.ContactHelper do
  alias OpenApiSpex.Schema

  def shared_props(props \\ %{}),
    do:
      Map.merge(
        %{
          name: %Schema{
            type: :string,
            description: "Contact's first name and last name",
            nullable: false
          },
          email: %Schema{
            type: :string,
            format: :email,
            description: "Contact's email address",
            nullable: true
          },
          phone_number: %Schema{
            type: :string,
            description:
              "Contact's phone number in the general international format for telephone numbers (E.164)",
            nullable: true
          },
          notify: %Schema{
            type: :boolean,
            default: true,
            description:
              "Set to `false` if the contact should not receive SMS and email notifications regarding the status of this shipment",
            nullable: false
          }
        },
        props
      )

  def shared_example(example \\ %{}),
    do:
      Map.merge(
        %{
          "name" => "John Smith",
          "email" => "john@smith.com",
          "phone_number" => "+1 202-555-0199",
          "notify" => false
        },
        example
      )
end

defmodule FraytElixirWeb.API.V2x1.Schemas.Contact do
  require OpenApiSpex
  alias FraytElixirWeb.API.V2x1.Schemas.ContactHelper

  OpenApiSpex.schema(%{
    title: "Contact",
    description: "A contact",
    type: :object,
    properties: ContactHelper.shared_props(),
    required: [:name],
    example: ContactHelper.shared_example()
  })
end
