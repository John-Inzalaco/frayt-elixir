defmodule FraytElixir.Test.FakeTurn do
  def call_api(method, path, payload, opts),
    do: build_response(method, String.split(path, "/"), payload, opts)

  def build_response(:post, ["person", "search_async"], %{} = request_params, []) do
    {:ok,
     %{
       "message" => %{
         "code" => "9200",
         "message" => "The operation completed successfully.",
         "request_uuid" => "21aac715-ada2-409a-952d-7610873ebfde"
       },
       "candidate_consent_url" =>
         "https://partners.turning.io/consent/HG6qlUzrxv5jEXhqmeywDRL_zpRQ9pe9?first_name=Alec&last_name=Sadler&phone_number=18884998876&email=contact%40turning.io&email_candidate=True&reference_id=ABC12345&redirect_url=https%3A%2F%2Fturning.io",
       "email" => request_params.email,
       "email_candidate" => true,
       "first_name" => request_params.first_name,
       "last_name" => request_params.last_name,
       "phone_number" => request_params.phone_number,
       "redirect_url" => "",
       "reference_id" => request_params.reference_id,
       "email_status" => %{
         "message" => "The notification email is on our queue, it will be delivered shortly",
         "status" => 200
       },
       "sms_status" => %{
         "message" => "SMS queued to be sent",
         "status" => 200
       },
       "uuid" => "12d6d04a-45df-4f02-9d2c-a1db2b2391bf",
       "worker_id" => "5c8f690c-0cc5-4063-beb8-8a140ff3abc6"
     }}
  end

  def build_response(:get, ["person", worker_id, "status"], _, _) do
    {:ok,
     %{
       "dashboard_url" => "https://partners.turning.io/workers/" <> worker_id,
       "state" => "approved",
       "turn_id" => "C1234567890",
       "worker_email" => "contact@turning.io",
       "worker_id" => worker_id
     }}
  end
end
