defmodule FraytElixir.Branch do
  alias FraytElixir.Drivers.Driver
  alias FraytElixir.Accounts.User
  alias FraytElixir.Shipment.Address

  defp get_config(key, default \\ nil),
    do: Application.get_env(:frayt_elixir, __MODULE__, []) |> Keyword.get(key, default)

  def request(method, route, payload \\ %{}, opts \\ []) do
    caller = get_config(:api_caller, &FraytElixir.Branch.call_api/4)
    org_id = get_config(:org_id)

    caller.(method, "organizations/#{org_id}" <> route, payload, opts)
  end

  def create_wallet(%Driver{
        id: employee_id,
        birthdate: birthdate,
        first_name: first_name,
        last_name: last_name,
        ssn: ssn,
        phone_number: phone_number,
        user: %User{email: email},
        address: %Address{
          address: address,
          address2: address2,
          city: city,
          country_code: country_code,
          state_code: state_code,
          zip: zip
        }
      }) do
    request(
      :post,
      "/employees/#{employee_id}/wallets",
      %{
        create_employee: true,
        order_card: false,
        date_of_birth: birthdate,
        email_address: email,
        first_name: first_name,
        last_name: last_name,
        ssn: ssn,
        phone_number: phone_number && ExPhoneNumber.format(phone_number, :e164),
        address: %{
          address_1: address,
          address_2: address2,
          city: city,
          country: country_code,
          postal_code: zip,
          state: state_code
        }
      },
      []
    )
  end

  def create_disbursement(%Driver{id: employee_id} = driver, attrs) do
    payload =
      attrs |> Map.take([:external_id, :amount, :description]) |> Map.put(:type, "DEPOSIT")

    request(:post, "/employees/#{employee_id}/disbursements", payload, driver: driver)
  end

  def call_api(method, route, payload, opts) do
    request_url = get_config(:api_url) <> route

    case send_request(method, request_url, payload, opts) do
      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        extract_response(status_code, body)

      {:error, error} ->
        {:error, error}
    end
  end

  defp extract_response(status_code, body) when status_code < 300, do: {:ok, Jason.decode!(body)}

  defp extract_response(status_code, body) do
    error =
      case Jason.decode(body) do
        {:ok, b} -> b
        _ -> body
      end

    {:error, status_code, error}
  end

  defp send_request(method, url, payload, opts),
    do:
      apply(HTTPoison, method, [
        url,
        Jason.encode!(payload),
        build_headers(opts),
        [recv_timout: 15_000]
      ])

  defp build_headers(opts),
    do: [
      {"Content-type", Keyword.get(opts, :content_type, "application/json")},
      {"apikey", get_config(:api_key)}
    ]
end
