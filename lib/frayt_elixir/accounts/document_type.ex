defmodule FraytElixir.Accounts.DocumentType do
  @types [
    :eula,
    :delivery_agreement,
    :responsibility_agreement,
    :terms_of_service,
    :privacy_policy,
    :driver_agreement
  ]

  use FraytElixir.Type.Enum,
    types: @types,
    names: [
      eula: "EULA"
    ]
end
