defmodule FraytElixir.Integrations.Walmart do
  alias Ecto.Changeset
  alias FraytElixir.Shipment
  alias FraytElixir.Shipment.{Match, MatchStop, MatchStateTransition, MatchStopStateTransition}
  alias FraytElixir.Matches
  alias FraytElixirWeb.Webhook.WalmartView

  @key_version Application.compile_env(:frayt_elixir, :walmart_key_version)
  @consumer_id Application.compile_env(:frayt_elixir, :walmart_consumer_id)

  @tip_deadline_days 14

  def get_walmart_pem() do
    if Application.get_env(:frayt_elixir, :environment) in [:prod, :dev] do
      case Application.get_env(:frayt_elixir, :walmart_private_pem, nil) do
        nil ->
          Application.fetch_env!(:frayt_elixir, :walmart_private_pem_file_location)
          |> File.read!()

        pem ->
          pem
      end
    end
  end

  @webhook_url Application.compile_env(:frayt_elixir, :walmart_webhook_url)

  def put_auth_header(headers, _) do
    if Application.get_env(:frayt_elixir, :environment) in [:prod, :dev] do
      [pem_entry] = get_walmart_pem() |> :public_key.pem_decode()
      private_key = :public_key.pem_entry_decode(pem_entry)
      timestamp = System.os_time(:millisecond)

      auth_signature =
        "#{@consumer_id}\n#{timestamp}\n#{@key_version}\n"
        |> :public_key.sign(:sha256, private_key)
        |> Base.encode64()

      headers ++
        [
          {"WM_CONSUMER.ID", @consumer_id},
          {"WM_CONSUMER.INTIMESTAMP", timestamp},
          {"WM_SEC.KEY_VERSION", @key_version},
          {"WM_SEC.AUTH_SIGNATURE", auth_signature}
        ]
    else
      headers
    end
  end

  @ignored_match_states [
    :assigning_driver,
    :accepted,
    :scheduled,
    :pending,
    :unable_to_pickup,
    :inactive,
    :charged
  ]

  @ignored_stop_states [:delivered, :undeliverable]

  def build_webhook_request(_, %Match{state: state}, nil) when state in @ignored_match_states,
    do: []

  def build_webhook_request(
        _,
        %Match{state: :picked_up, match_stops: [%MatchStop{state: state} | _]},
        nil
      )
      when state in @ignored_stop_states,
      do: []

  def build_webhook_request(_, _match, %MatchStateTransition{to: state})
      when state in @ignored_match_states,
      do: []

  def build_webhook_request(_, _match, %MatchStopStateTransition{to: state})
      when state in @ignored_stop_states,
      do: []

  def build_webhook_request(_, match, _) do
    [
      {
        @webhook_url <> "?clientId=#{match.meta["client_id"]}",
        WalmartView.render("match_webhook.json", %{match: match})
      }
    ]
  end

  def update_tip_price(match, tip) do
    [first | rest] = match.match_stops

    with :ok <- validate_tip_deadline(match),
         attrs <- %{match_stops: [%{id: first.id, tip_price: tip} | rest]},
         {:ok, %Match{} = match} <- Matches.update_match(match, attrs) do
      {:ok, match}
    end
  end

  defp validate_tip_deadline(match) do
    case Shipment.find_transition(match, :completed, :asc) do
      nil ->
        :ok

      stt ->
        # 14 days (in seconds)
        deadline = @tip_deadline_days * 24 * 60 * 60
        time_elapsed = NaiveDateTime.utc_now() |> NaiveDateTime.diff(stt.inserted_at, :second)
        [first_stop | _] = match.match_stops

        if time_elapsed < deadline,
          do: :ok,
          else:
            Changeset.change(first_stop) |> Changeset.add_error(:tip_price, "deadline expired")
    end
  end

  def get_error_code(changeset) do
    Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
    |> error_code()
  end

  defp error_code(%{match_stops: [%{destination_address: %{address: _}} | _]}) do
    "INVALID_DROPOFF_ADDRESS"
  end

  defp error_code(%{match_stops: [%{tip_price: _} | _]}) do
    "TIP_MUST_BE_POSITIVE"
  end

  defp error_code(%{origin_address: %{address: _}}) do
    "INVALID_PICKUP_ADDRESS"
  end

  defp error_code(%{sender: %{phone_number: _}}) do
    "INVALID_PICKUP_PHONE_NUMBER"
  end

  defp error_code(%{driver_total_pay: _}) do
    "TIP_ALREADY_APPLIED"
  end

  defp error_code(%{tip_price: ["deadline expired"]}) do
    "TIP_DEADLINE_EXPIRED"
  end

  defp error_code(%{tip_price: _}) do
    "TIP_MUST_BE_POSITIVE"
  end

  defp error_code(%{tip: ["is invalid"]}) do
    "TIP_MUST_BE_INTEGER"
  end

  defp error_code(_), do: "OTHER"
end
