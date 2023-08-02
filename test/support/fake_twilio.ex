defmodule FraytElixir.Test.FakeTwilio do
  def send_message(body: _, from: _, to: "000"),
    do:
      {:error,
       %{
         "code" => 21_211,
         "message" => "The 'To' number 000 is not a valid phone number.",
         "more_info" => "https://www.twilio.com/docs/errors/21211",
         "status" => 400
       }, 400}

  def send_message(body: body, from: from, to: to) do
    {:ok,
     %ExTwilio.Message{
       account_sid: "ACe26f1b06bc2beffb15e0315583087d7d",
       api_version: "2010-04-01",
       body: body,
       date_created: "Mon, 13 Jul 2020 15:41:44 +0000",
       date_sent: nil,
       date_updated: "Mon, 13 Jul 2020 15:41:44 +0000",
       direction: "outbound-api",
       error_code: nil,
       error_message: nil,
       from: from,
       messaging_service_sid: nil,
       num_media: "0",
       num_segments: "1",
       price: nil,
       price_unit: "USD",
       sid: "SMa966f710be1843f3a8f9287b3d913e59",
       status: "queued",
       subresource_uri: nil,
       to: to,
       uri:
         "/2010-04-01/Accounts/ACe26f1b06bc2beffb15e0315583087d7d/Messages/SMa966f710be1843f3a8f9287b3d913e59.json"
     }}
  end
end
