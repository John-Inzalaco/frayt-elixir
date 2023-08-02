defmodule FraytElixirWeb.Webhook.TurnControllerTest do
  use FraytElixirWeb.ConnCase
  alias FraytElixir.Repo
  alias FraytElixir.Screenings.BackgroundCheck
  import FraytElixir.Factory

  describe "handle_webhooks" do
    @valid_params %{
      team_member_email: "contact@turning.io",
      original_state: "pending",
      dashboard_url: "http://partners.turning.io/workers/623580e8-9a76-462f-acc9-2a190be182fa",
      event_id: "11c42854-364e-481e-8e9b-22c21e9edeea",
      state: "approved",
      timestamp: :os.system_time(:seconds),
      worker_email: "alec@sadtech.ca",
      worker_id: "623580e8-9a76-462f-acc9-2a190be182fa"
    }

    test "handles approved webhook", %{conn: conn} do
      background_check =
        insert(:background_check,
          turn_id: "623580e8-9a76-462f-acc9-2a190be182fa",
          turn_state: "processing",
          driver: build(:driver, state: :pending_approval)
        )

      conn = post(conn, Routes.webhook_turn_path(conn, :handle_webhooks), @valid_params)

      assert response(conn, 204)

      assert %BackgroundCheck{turn_state: "approved"} =
               Repo.get(BackgroundCheck, background_check.id)
    end
  end
end
