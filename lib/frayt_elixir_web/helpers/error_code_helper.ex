defmodule FraytElixirWeb.ErrorCodeHelper do
  @error_statuses [
    forbidden: [:invalid_credentials, :invalid_user],
    unprocessable_entity: [
      :invalid_password,
      :missing_address,
      :invalid_file,
      :card_error,
      :no_stripe_agreement,
      :already_in_fleet,
      :not_in_fleet
    ],
    unauthorized: [:unauthenticated, :invalid_token, :disabled],
    not_found: [:no_resource_found],
    ok: [:already_authenticated],
    bad_request: [:invalid_state]
  ]

  def get_error_status(type) do
    Enum.find_value(@error_statuses, type, fn {code, types} ->
      if type in types, do: code
    end)
  end

  def get_error_message(type) do
    case type do
      :unauthenticated -> "You are not logged in"
      :invalid_token -> "Your token is invalid"
      :no_resource_found -> "Not found"
      :already_authenticated -> "You are already logged in"
      :invalid_file -> "Invalid file upload"
      :forbidden -> "Permission denied"
      :disabled -> "Your account has been disabled"
      type -> Phoenix.Naming.humanize(type)
    end
  end
end
