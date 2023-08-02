defmodule FraytElixir.Shipment.DeliveryBatches do
  alias FraytElixir.Repo
  alias FraytElixir.Import
  alias FraytElixir.{Accounts, Shipment, Matches}
  alias FraytElixir.Accounts.{Schedule, Location, Shipper}
  alias Ecto.Changeset
  import FraytElixir.AtomizeKeys
  alias Phoenix.PubSub
  alias FraytElixir.PaginationQueryHelpers
  alias FraytElixir.Webhooks.WebhookSupervisor

  alias FraytElixir.Shipment.{
    Address,
    DeliveryBatch,
    BatchStateTransition,
    DeliveryBatchSupervisor
  }

  alias FraytElixir.PaginationQueryHelpers

  def list_batches(%{state: state, query: query} = args),
    do:
      DeliveryBatch
      |> DeliveryBatch.filter_by_query(query)
      |> DeliveryBatch.filter_by_state(state)
      |> PaginationQueryHelpers.list_record(args, [
        :address,
        :match_stops,
        :matches,
        :state_transitions,
        :location,
        shipper: [location: :company]
      ])

  def create_delivery_batch(attrs, shipper, [route: route] = _options \\ [route: true]) do
    company_settings = Shipment.get_company_settings(shipper)

    attrs =
      attrs
      |> Matches.build_stops([], company_settings)
      |> Map.put(:address, Map.get(attrs, :origin_address, Map.get(attrs, :address)))

    with {:ok, delivery_batch} <-
           %DeliveryBatch{}
           |> DeliveryBatch.changeset(attrs)
           |> Changeset.put_assoc(:shipper, shipper)
           |> Repo.insert() do
      delivery_batch = delivery_batch |> Repo.preload(:state_transitions)
      WebhookSupervisor.start_batch_webhook_sender(delivery_batch)
      start_routing(delivery_batch, route)

      {:ok, delivery_batch}
    end
  end

  def create_delivery_batch_from_csv(
        %{"pickup_at" => pickup_at, "location_id" => location_id} = attrs,
        %Plug.Upload{path: path},
        opts = _options \\ [route: true]
      ) do
    case Accounts.get_location!(location_id) do
      %Location{shippers: [%Shipper{} = shipper | _], address: %Address{} = address} = location ->
        schedule = Accounts.get_schedule_for_location(location)
        stops = parse_csv(path, schedule, pickup_at)

        attrs =
          attrs
          |> atomize_keys()
          |> Map.put(:service_level, 1)
          |> Map.put(:stops, stops)
          |> Map.put(:origin_address, address)

        create_delivery_batch(attrs, shipper, opts)

      _ ->
        {:error, :invalid_location}
    end
  end

  defp start_routing(delivery_batch, false), do: {:ok, delivery_batch}

  defp start_routing(delivery_batch, true) do
    DeliveryBatchSupervisor.start_routing(delivery_batch)
  end

  defp parse_csv(path, schedule, pickup_at),
    do:
      path
      |> File.stream!()
      |> CSV.decode()
      |> Enum.to_list()
      |> Import.convert_to_map_list()
      |> Enum.map(&atomize_keys/1)
      |> Enum.map(&build_schedule_sla_timer(&1, schedule, pickup_at))
      |> Enum.map(&build_match_stop_items(&1))
      |> Enum.map(&build_match_stop_recipient(&1))

  def get_delivery_batch(id) do
    DeliveryBatch
    |> Repo.get(id)
    |> Repo.preload([:matches, location: [:company]])
  end

  def cancel_delivery_batch(%DeliveryBatch{matches: matches} = batch) do
    with {:ok, batch, _} <- update_state(batch, :canceled),
         :ok <- matches |> Enum.each(&Shipment.shipper_cancel_match(&1)),
         batch <- get_delivery_batch(batch.id) do
      {:ok, batch}
    end
  end

  def update_batch_status(batches, job_id, status) do
    batches
    |> Enum.map(fn %DeliveryBatch{id: id} = batch ->
      case id do
        ^job_id -> Map.put(batch, :state, status)
        _ -> batch
      end
    end)
  end

  def update_state(%DeliveryBatch{state: from, id: batch_id} = batch, state, notes \\ nil) do
    with {:ok, {batch, transition}} <-
           Repo.transaction(fn repo ->
             transition =
               %BatchStateTransition{}
               |> BatchStateTransition.changeset(%{
                 from: from,
                 to: state,
                 notes: notes,
                 batch_id: batch_id
               })
               |> repo.insert!()

             batch = batch |> DeliveryBatch.changeset(%{state: state}) |> repo.update!()

             {batch, transition}
           end) do
      PubSub.broadcast!(
        FraytElixir.PubSub,
        "batch_state_transitions:#{batch.id}",
        {batch, transition}
      )

      {:ok, batch, transition}
    end
  end

  def build_match_stop_recipient(
        %{recipient_name: name, recipient_email: email, recipient_phone: phone} = attrs
      )
      when not is_nil(name) or not is_nil(email) or not is_nil(phone),
      do:
        Map.put(attrs, :recipient, %{
          name: name,
          email: email,
          phone_number: phone
        })

  def build_match_stop_recipient(attrs), do: attrs

  def build_match_stop_items(
        %{
          width: width,
          length: length,
          height: height,
          pieces: pieces,
          description: description,
          weight: weight
        } = attrs
      )
      when is_number(width) and is_number(length) and is_number(height) and is_number(pieces) do
    items = Map.get(attrs, :items, [])

    match_stop_item = %{
      weight: weight,
      pieces: pieces,
      width: width,
      length: length,
      height: height,
      volume: length * width * height * pieces,
      description: description
    }

    Map.put(attrs, :items, [match_stop_item | items])
  end

  def build_match_stop_items(
        %{
          width: width,
          length: length,
          height: height,
          description: _description,
          weight: _weight,
          pieces: pieces
        } = attrs
      ),
      do:
        attrs
        |> Map.put(:width, parse(width))
        |> Map.put(:length, parse(length))
        |> Map.put(:height, parse(height))
        |> Map.put(:pieces, parse(pieces))
        |> build_match_stop_items()

  def build_match_stop_items(attrs), do: attrs

  def parse(""), do: 1
  def parse(num) when is_number(num), do: num

  def parse(string_num) do
    case Integer.parse(string_num) do
      :error -> 1
      {value, _} -> value
    end
  end

  def build_schedule_sla_timer(
        %{scheduled_dropoff: scheduled_dropoff} = attrs,
        _schedule,
        _pickup_at
      )
      when not is_nil(scheduled_dropoff) and scheduled_dropoff != "" and
             is_binary(scheduled_dropoff) do
    case scheduled_dropoff |> NaiveDateTime.from_iso8601() do
      {:ok, dropoff_by} -> Map.put(attrs, :dropoff_by, dropoff_by)
      _ -> attrs
    end
  end

  def build_schedule_sla_timer(attrs, schedule, pickup_at) when is_binary(pickup_at) do
    case pickup_at |> NaiveDateTime.from_iso8601() do
      {:ok, pickup_at} -> build_schedule_sla_timer(attrs, schedule, pickup_at)
      _ -> attrs
    end
  end

  def build_schedule_sla_timer(attrs, %Schedule{sla: sla}, %NaiveDateTime{} = pickup_at)
      when not is_nil(sla),
      do: Map.put(attrs, :dropoff_by, NaiveDateTime.add(pickup_at, sla * 60))

  def build_schedule_sla_timer(attrs, _, _), do: attrs
end
