defmodule FraytElixir.Test.FakeBranch do
  def call_api(method, path, payload, opts),
    do: build_response(method, String.split(path, "/"), payload, opts)

  def build_response(
        :post,
        ["organizations", _org_id, "employees", employee_id, "wallets"],
        payload,
        _opts
      ) do
    cond do
      Date.compare(payload.date_of_birth, ~D[1910-01-01]) == :lt ->
        {:error, 500,
         %{
           "timestamp" => "2021-09-27T14:57:32.006+00:00",
           "status" => 500,
           "error" => "Internal Server Error",
           "message" => "Could not initialize user"
         }}

      payload.email_address =~ "timeout" ->
        {:error, %HTTPoison.Error{id: nil, reason: :timeout}}

      true ->
        {:ok,
         %{
           "account_number" => "string",
           "employee_id" => employee_id,
           "has_activated_card" => false,
           "onboarding_link" => "string",
           "routing_number" => "string",
           "status" => "UNCLAIMED",
           "time_created" => current_time(),
           "time_last_initialization_attempted" => current_time()
         }}
    end
  end

  def build_response(
        :post,
        ["organizations", _org_id, "employees", employee_id, "disbursements"],
        %{
          amount: amount,
          description: description,
          external_id: external_id,
          type: type
        },
        driver: driver
      ) do
    cond do
      amount == 666 ->
        {:error, %HTTPoison.Error{id: nil, reason: :timeout}}

      is_nil(driver.wallet_state) || driver.wallet_state == :NOT_CREATED ->
        {:ok,
         %{
           "amount" => amount,
           "description" => description,
           "employee_id" => employee_id,
           "external_id" => external_id,
           "type" => type,
           "metadata" => %{},
           "status" => "FAILED",
           "status_reason" => "string",
           "time_created" => current_time(),
           "time_modified" => current_time()
         }}

      true ->
        {:ok,
         %{
           "amount" => amount,
           "description" => description,
           "employee_id" => employee_id,
           "external_id" => external_id,
           "type" => type,
           "metadata" => %{},
           "status" => "succeeded",
           "time_created" => current_time(),
           "time_modified" => current_time()
         }}
    end
  end

  defp current_time, do: DateTime.utc_now() |> DateTime.to_iso8601()
end
