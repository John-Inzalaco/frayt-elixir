defmodule FraytElixir.Mailer.DeliverLaterStrategy do
  alias FraytElixir.Notifications.Slack
  @behaviour Bamboo.DeliverLaterStrategy

  # This is a strategy for delivering later using Task.async
  def deliver_later(adapter, email, config) do
    Task.start_link(fn ->
      # Always call deliver on the adapter so that the email is delivered.
      try do
        adapter.deliver(email, config)
      rescue
        e in Bamboo.ApiError -> Slack.send_email_message(email, "Failed to Send Email", e.message)
      end
    end)
  end
end
