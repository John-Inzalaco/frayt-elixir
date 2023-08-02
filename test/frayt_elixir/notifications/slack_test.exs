defmodule FraytElixir.Notifications.SlackTest do
  use FraytElixir.DataCase
  alias FraytElixir.Test.FakeSlack
  alias FraytElixir.Shipment.Match
  alias FraytElixir.Accounts.AdminUser
  import FraytElixir.Notifications.Slack

  setup do
    FakeSlack.clear_messages()
  end

  describe "send_message!/3" do
    test "sends message" do
      send_message!(:dispatch, "message")

      assert [{"#test-dispatch", "message"}] = FakeSlack.get_messages()
    end

    test "throws error on timeout" do
      assert_raise HTTPoison.Error, fn ->
        send_message!(:dispatch, "this will timeout")
      end
    end
  end

  describe "send_message/3" do
    test "sends message" do
      send_message(:dispatch, "message")

      assert [{"#test-dispatch", "message"}] = FakeSlack.get_messages()
    end

    test "returns error tuple" do
      assert {:error, :httpoison_error} = send_message(:dispatch, "this will timeout")
    end
  end

  describe "send_shipper_message/1" do
    test "sends commercial shipper message with hubspot url" do
      shipper =
        insert(:shipper,
          first_name: "Jane",
          last_name: "Doe",
          commercial: true,
          company: "Some Company Inc",
          hubspot_id: "533",
          phone: "513-888-7766",
          address: nil
        )

      assert {:ok, _, :ok} = send_shipper_message(shipper)

      assert [{"#test-shippers", message}] = FakeSlack.get_messages()

      assert message =~ "<!subteam^S01FQFMSYPN> Shipper Jane Doe"

      assert message =~
               "has created a business account under the company Some Company Inc and has no assigned sales rep. You can reach them at 513-888-7766. <https://app.hubspot.com/contacts/6023447/contact/533|View in Hubspot>"
    end

    test "notifies sales rep with slack_id" do
      shipper =
        insert(:shipper,
          first_name: "Jane",
          last_name: "Doe",
          commercial: true,
          company: "Some Company Inc",
          hubspot_id: "533",
          phone: "513-888-7766",
          address: nil,
          sales_rep: insert(:admin_user, slack_id: "abcdefg")
        )

      assert {:ok, _, :ok} = send_shipper_message(shipper)

      assert [{"#test-shippers", message}] = FakeSlack.get_messages()

      assert message =~ "<@abcdefg> Shipper Jane Doe"
    end

    test "sends commercial shipper message without hubspot url" do
      shipper =
        insert(:shipper,
          first_name: "Jane",
          last_name: "Doe",
          commercial: true,
          company: "Some Company Inc",
          phone: "513-888-7766",
          address: %{
            city: "Cincinnati",
            state: "OH"
          }
        )

      assert {:ok, _, :ok} =
               send_shipper_message(shipper,
                 hubspot_error: %{
                   "message" => "Contact already exists. Existing ID: 10578151"
                 }
               )

      assert {:ok, _, :ok} = send_shipper_message(shipper, hubspot_error: :timeout)

      assert [{"#test-shippers", timeout_message}, {"#test-shippers", error_message}] =
               FakeSlack.get_messages()

      assert error_message =~ "<!subteam^S01FQFMSYPN> Shipper Jane Doe"

      assert error_message =~
               "from Cincinnati, OH has created a business account under the company Some Company Inc and has no assigned sales rep. You can reach them at 513-888-7766. Import to Hubspot failed for this shipper. Reason: Contact already exists. Existing ID: 10578151"

      assert timeout_message =~ "Reason: :timeout"
    end

    test "sends non-commercial shipper account slack message - not currently in use" do
      shipper =
        insert(:shipper,
          first_name: "Jane",
          last_name: "Doe",
          phone: "513-888-7766",
          address: %{
            city: "Cincinnati",
            state: "OH"
          }
        )

      assert {:ok, _, :ok} = send_shipper_message(shipper)

      assert [{"#test-shippers", message}] = FakeSlack.get_messages()

      assert message =~
               "from Cincinnati, OH has created an account and has no assigned sales rep. You can reach them at 513-888-7766."
    end

    test "can override message" do
      shipper =
        insert(:shipper,
          first_name: "Jane",
          last_name: "Doe",
          phone: "513-888-7766",
          address: %{
            city: "Cincinnati",
            state: "OH"
          }
        )

      assert {:ok, _, :ok} = send_shipper_message(shipper, message: "test message")

      assert [{"#test-shippers", message}] = FakeSlack.get_messages()

      assert message =~ "test message"
    end
  end

  describe "send_match_message/3" do
    test "sends message" do
      %Match{id: match_id} = match = insert(:match)

      assert {:ok, _, %{"message" => %{"text" => message, "ts" => ts}}} =
               send_match_message(match, "start_thread test message")

      assert message =~ ~r/http:.+#{match.id}.+#{match.shortcode}.+start_thread test message/

      assert %Match{
               id: ^match_id,
               slack_thread_id: ^ts
             } = Repo.get(Match, match_id)
    end

    test "sends scheduled match message" do
      %Match{id: match_id} =
        match =
        insert(:match,
          scheduled: true,
          pickup_at: ~N[2020-10-10 12:00:00],
          dropoff_at: ~N[2020-10-10 14:00:00]
        )

      assert {:ok, _, %{"message" => %{"text" => message, "ts" => ts}}} =
               send_match_message(match, "start_thread test message")

      assert message =~
               ~r/Match <.+> \(dash\) scheduled for pickup at Oct 10, 2020, 08:00:00 AM EDT and delivery at Oct 10, 2020, 10:00:00 AM EDT from Cincinnati, OH to Cincinnati, OH/

      assert %Match{
               id: ^match_id,
               slack_thread_id: ^ts
             } = Repo.get(Match, match_id)
    end

    test "sends subsequent match messages to thread" do
      %Match{id: match_id} = match = insert(:match)

      assert {:ok,
              %Match{
                id: ^match_id
              } = match,
              %{"message" => %{"ts" => ts}}} =
               send_match_message(match, "start_thread test message")

      assert {:ok, _, %{"message" => %{"text" => message, "thread_ts" => ^ts}}} =
               send_match_message(match, "follow up message")

      assert message =~ "#{match.shortcode}> follow up message"
    end

    test "sends messages tagging assigned net ops if warning or danger" do
      %Match{network_operator: %AdminUser{slack_id: slack_id}} =
        match = insert(:match, network_operator: build(:network_operator))

      assert {:ok, _, %{"message" => %{"text" => message}}} =
               send_match_message(
                 match,
                 "start_thread test message",
                 :danger
               )

      assert message =~ ":octagonal_sign: <@#{slack_id}>"

      match = Repo.get(Match, match.id)

      assert {:ok, _, %{"message" => %{"text" => follow_up_message}}} =
               send_match_message(match, "follow up message", :warning)

      assert follow_up_message =~ ":warning: <@#{slack_id}>"
    end

    test "sends messages tagging @ops if no assignee and warning or danger" do
      match = insert(:match)

      assert {:ok, _, %{"message" => %{"text" => message}}} =
               send_match_message(
                 match,
                 "start_thread test message",
                 :danger
               )

      assert message =~ ":octagonal_sign: <!subteam"

      match = Repo.get(Match, match.id)

      assert {:ok, _, %{"message" => %{"text" => follow_up_message}}} =
               send_match_message(match, "follow up message", :warning)

      assert follow_up_message =~ ":warning: <!subteam"
    end
  end
end
