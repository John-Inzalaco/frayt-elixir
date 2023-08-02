defmodule FraytElixir.Notifications.Slack do
  alias FraytElixir.Shipment
  alias FraytElixir.Shipment.{Address, Match, MatchStop}
  alias FraytElixir.Accounts.{AdminUser, Shipper, User}
  alias FraytElixirWeb.DisplayFunctions
  alias FraytElixirWeb.Router.Helpers
  alias FraytElixirWeb.Endpoint
  alias Ecto.Association.NotLoaded
  alias FraytElixir.Repo

  @levels [
    :alert,
    :warning,
    :danger
  ]

  @level_icons %{
    alert: "",
    warning: ":warning:",
    danger: ":octagonal_sign:"
  }

  defp get_config(key, default \\ nil),
    do: Application.get_env(:frayt_elixir, __MODULE__, []) |> Keyword.get(key, default)

  def send_message!(channel, message, options \\ %{}) do
    channel_name = get_channel(channel)

    send_message = get_config(:send_message, &Slack.Web.Chat.post_message/3)

    send_message.(channel_name, message, options)
  end

  def send_message(channel, message, options \\ %{}) do
    send_message!(channel, message, options)
  rescue
    HTTPoison.Error ->
      {:error, :httpoison_error}
  end

  def send_payment_message(match, message, level \\ :alert)

  def send_payment_message(match, message, level) when level in @levels do
    case send_message(:payments, build_match_message(match, message, level)) do
      %{"ok" => true, "message" => _msg} = response ->
        {:ok, match, response}

      {:error, error} ->
        {:error, error}

      error ->
        {:error, error}
    end
  end

  def send_email_message(email, message, error_message),
    do:
      send_message(
        :emails,
        message,
        %{
          blocks:
            Jason.encode!([
              %{
                "type" => "section",
                "text" => %{
                  "type" => "mrkdwn",
                  "text" => "*Failed to Send Email*\nView the error message for more details."
                }
              },
              %{
                "type" => "divider"
              },
              %{
                "type" => "section",
                "text" => %{
                  "type" => "mrkdwn",
                  "text" =>
                    [
                      Subject: email.subject,
                      To: get_address_string(email.to),
                      CC: get_address_string(email.cc),
                      BCC: get_address_string(email.bcc),
                      From: get_address_string(email.from),
                      Content: "\n" <> email.text_body
                    ]
                    |> Enum.filter(&elem(&1, 1))
                    |> Enum.map_join("\n", &"*#{Atom.to_string(elem(&1, 0))}:* #{elem(&1, 1)}")
                }
              },
              %{
                "type" => "divider"
              }
            ]),
          attachments:
            Jason.encode!([
              %{
                "blocks" => [
                  %{
                    "type" => "section",
                    "text" => %{
                      "type" => "mrkdwn",
                      "text" => "*Error Message*\n```#{error_message}```"
                    }
                  }
                ]
              }
            ])
        }
      )

  def send_match_message(match, message, level \\ :alert, opts \\ [])

  def send_match_message(%Match{slack_thread_id: nil} = match, message, level, opts) do
    channel = Keyword.get(opts, :channel, :dispatch)

    with %Match{slack_thread_id: slack_thread_id} = match <- Shipment.get_match(match.id) do
      send_match_message(match, message, level, slack_thread_id, channel)
    end
  end

  def send_match_message(%Match{} = match, message, level, opts) do
    channel = Keyword.get(opts, :channel, :dispatch)
    slack_thread_id = Keyword.get(opts, :thread_id, match.slack_thread_id)

    send_match_message(match, message, level, slack_thread_id, channel)
  end

  def send_match_message(match, message, level, nil, channel)
      when level in @levels do
    with %{"ok" => true, "message" => %{"ts" => thread_id}} = response <-
           send_message(channel, build_match_message(match, message, level)),
         {:ok, %Match{} = match} <- Shipment.update_match_slack_thread(match, thread_id) do
      {:ok, match, response}
    else
      {:error, error} -> {:error, error}
      error -> {:error, error}
    end
  end

  def send_match_message(match, message, level, slack_thread_id, channel)
      when level in @levels,
      do:
        {:ok, match,
         send_message(
           channel,
           build_match_message(match, message, level),
           %{thread_ts: slack_thread_id}
         )}

  def send_shipper_message(shipper, opts \\ []) do
    shipper = Repo.preload(shipper, sales_rep: [:user])
    message = build_shipper_message(shipper, opts)

    {:ok, shipper, send_message(:shippers, message)}
  end

  defp build_shipper_prefix(shipper) do
    get_sales_tag(shipper) <>
      "Shipper #{DisplayFunctions.full_name(shipper)} (#{shipper.user.email}) "
  end

  defp build_shipper_message(shipper, message: message) do
    build_shipper_prefix(shipper) <> message
  end

  defp build_shipper_message(shipper, opts) do
    message =
      build_shipper_prefix(shipper) <>
        display_shipper_address(shipper) <> "has created "

    sales_rep_message =
      case shipper do
        %Shipper{sales_rep: %AdminUser{name: name, user: %User{email: email}}} ->
          " belonging to sales rep #{name} (#{email})"

        _ ->
          " and has no assigned sales rep"
      end

    if shipper.commercial do
      message =
        message <>
          "a business account under the company #{shipper.company}#{sales_rep_message}. You can reach them at #{DisplayFunctions.display_shipper_phone(shipper.phone)}. "

      hubspot_contact_url = get_hubspot_contact_url(shipper.hubspot_id)

      message =
        case hubspot_contact_url do
          nil ->
            reason =
              case opts[:hubspot_error] do
                %{"message" => message} -> message
                error -> inspect(error)
              end

            message <>
              "Import to Hubspot failed for this shipper. Reason: #{reason}"

          _ ->
            message <> "<#{hubspot_contact_url}|View in Hubspot>"
        end

      message
    else
      message =
        message <>
          "an account#{sales_rep_message}. You can reach them at #{DisplayFunctions.display_shipper_phone(shipper.phone)}."

      message
    end
  end

  defp display_shipper_address(%Shipper{address: %Address{city: city, state: state}}),
    do: "from #{city}, #{state} "

  defp display_shipper_address(_), do: ""

  defp get_hubspot_contact_url(nil), do: nil

  defp get_hubspot_contact_url(contact_id),
    do:
      Application.get_env(
        :frayt_elixir,
        :hubspot_base_url,
        "https://app.hubspot.com/contacts/6023447/"
      ) <> "contact/#{contact_id}"

  defp build_match_message(%Match{slack_thread_id: nil} = match, message, level) do
    icon = Map.get(@level_icons, level, "")

    "#{icon} #{get_ops_tag(match, level)}#{build_description(match)} #{message}"
    |> String.trim()
  end

  defp build_match_message(match, message, level) do
    icon = Map.get(@level_icons, level, "")

    "#{icon} #{get_ops_tag(match, level)}#{get_match_link(match)} #{message}"
    |> String.trim()
  end

  defp get_ops_tag(_match, level) when level not in [:warning, :danger], do: ""

  defp get_ops_tag(%Match{network_operator_id: nil}, _),
    do: "<!subteam^#{get_ops_id()}> "

  defp get_ops_tag(%Match{network_operator: %NotLoaded{}} = match, level),
    do: match |> Repo.preload(:network_operator) |> get_ops_tag(level)

  defp get_ops_tag(%Match{network_operator: %AdminUser{slack_id: slack_id}}, _),
    do: "<@#{slack_id}> "

  defp get_sales_tag(%Shipper{sales_rep: %AdminUser{slack_id: slack_id}}),
    do: "<@#{slack_id}> "

  defp get_sales_tag(%Shipper{sales_rep: nil}),
    do: "<!subteam^#{get_sales_id()}> "

  defp build_description(
         %Match{
           service_level: service_level,
           origin_address: %Address{city: origin_city, state_code: origin_state},
           shipper: %Shipper{first_name: first_name, last_name: last_name},
           match_stops: [
             %MatchStop{
               destination_address: %Address{
                 city: destination_city,
                 state_code: destination_state
               }
             }
             | []
           ]
         } = match
       ),
       do:
         "Match #{get_match_link(match)} (#{service_level(service_level)}) #{scheduled(match)}from #{origin_city}, #{origin_state} to #{destination_city}, #{destination_state} by #{first_name} #{last_name}"

  defp build_description(
         %Match{
           service_level: service_level,
           origin_address: %Address{city: origin_city, state_code: origin_state},
           shipper: %Shipper{first_name: first_name, last_name: last_name},
           match_stops:
             [
               %MatchStop{}
               | _
             ] = stops
         } = match
       ),
       do:
         stops
         |> Enum.reduce(
           "Match #{get_match_link(match)} (#{service_level(service_level)}) #{scheduled(match)}from #{origin_city}, #{origin_state} to the following destinations:",
           fn %{destination_address: %{formatted_address: address}}, acc ->
             acc <> "| Destination: #{address} |, "
           end
         )
         |> (&(&1 <> "by #{first_name} #{last_name}")).()

  defp build_description(%Match{match_stops: %NotLoaded{}} = match),
    do:
      match
      |> Repo.preload(origin_address: [], match_stops: [:destination_address])
      |> build_description()

  defp build_description(%Match{shipper: %NotLoaded{}} = match),
    do:
      match
      |> Repo.preload(:shipper)
      |> build_description()

  defp scheduled(%Match{
         scheduled: true,
         pickup_at: pickup_at,
         dropoff_at: dropoff_at,
         origin_address: origin_address
       })
       when not is_nil(dropoff_at),
       do:
         "scheduled for pickup at #{DisplayFunctions.display_date_time_long(pickup_at, origin_address)} and delivery at #{DisplayFunctions.display_date_time_long(dropoff_at, origin_address)} "

  defp scheduled(%Match{
         scheduled: true,
         pickup_at: pickup_at,
         origin_address: origin_address
       }),
       do:
         "scheduled for pickup at #{DisplayFunctions.display_date_time_long(pickup_at, origin_address)} "

  defp scheduled(_),
    do: ""

  defp get_match_link(%Match{id: id, shortcode: shortcode}),
    do:
      "<" <> Endpoint.url() <> Helpers.match_details_path(Endpoint, :add, id) <> "|#{shortcode}>"

  defp service_level(service_level),
    do: Shipment.service_level(service_level)

  defp get_address_string(emails) when is_list(emails) do
    emails
    |> Enum.map_join(", ", &elem(&1, 1))
    |> case do
      "" -> nil
      address -> address
    end
  end

  defp get_address_string({_, ""}), do: nil
  defp get_address_string({_, email}), do: email

  def get_ops_id, do: get_config(:ops_id)

  defp get_sales_id, do: get_config(:sales_id)

  defp get_channel(:dispatch), do: get_config(:dispatch_channel)
  defp get_channel(:dispatch_attempts), do: get_config(:dispatch_attempts_channel)
  defp get_channel(:sales), do: get_config(:sales_channel)
  defp get_channel(:drivers), do: get_config(:drivers_channel)
  defp get_channel(:shippers), do: get_config(:shippers_channel)
  defp get_channel(:payments), do: get_config(:payments_channel)
  defp get_channel(:emails), do: get_config(:emails_channel)
  defp get_channel(:appsignal), do: get_config(:appsignal_channel)
  defp get_channel(:errors), do: get_config(:errors_channel)
  defp get_channel(:high_priority_dispatch), do: get_config(:high_priority_dispatch_channel)
end
