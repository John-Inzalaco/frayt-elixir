defmodule FraytElixir.WebhooksTest do
  use FraytElixir.DataCase
  alias FraytElixir.Webhooks
  import FraytElixir.Test.WebhookHelper

  describe "send_webhook/3" do
    test "sends webhook" do
      company =
        insert(:company,
          webhook_config: %{auth_header: "Authorization", auth_token: "Bearer token"},
          webhook_url: "url"
        )

      webhook_request =
        insert(:webhook_request, company_id: company.id, webhook_type: "match")
        |> Repo.preload(:company)
        |> Map.put(:payload, %{"webhook_body" => "content"})

      assert {:ok, response} =
               Webhooks.send_webhook(
                 webhook_request,
                 listen_webhook_post(self())
               )

      assert_received ^response
    end

    test "fails with nil url" do
      company =
        insert(:company,
          webhook_config: %{auth_header: "Authorization", auth_token: "Bearer token"},
          webhook_url: nil
        )

      webhook_request =
        insert(:webhook_request, company_id: company.id, webhook_type: "match")
        |> Repo.preload(:company)
        |> Map.put(:payload, %{"webhook_body" => "content"})

      assert {:error, :invalid_settings} =
               Webhooks.send_webhook(
                 webhook_request,
                 &webhook_post/4
               )
    end

    test "fails with missing settings" do
      company = insert(:company)

      webhook_request =
        insert(:webhook_request, company_id: company.id, webhook_type: "match")
        |> Repo.preload(:company)
        |> Map.put(:payload, %{"webhook_body" => "content"})

      assert {:error, :invalid_settings} =
               Webhooks.send_webhook(
                 webhook_request,
                 &webhook_post/4
               )
    end
  end
end
