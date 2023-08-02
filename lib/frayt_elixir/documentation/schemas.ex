use PhoenixSwagger

defmodule FraytElixir.Documentation.Schemas do
  def schema(schema_name, version \\ :v2)

  def schema(schemas, version) when is_list(schemas) do
    Enum.reduce(schemas, %{}, fn schema_name, acc ->
      Map.put(acc, schema_name, schema(schema_name, version))
    end)
  end

  def schema(:Match, _) do
    swagger_schema do
      title("Match")
      description("A Match")

      properties do
        items(Schema.ref(:MatchStopItems), "Items", required: true)

        origin_address(:string, "Origin Address",
          required: true,
          example: "1311 Vine St. Cincinnati, OH 45202"
        )

        destination_address(:string, "Destination Address",
          required: true,
          example: "1241 Elm St, Cincinnati, OH 45202"
        )

        service_level(:string, "Service Level\nDash = 1, Same Day = 2",
          required: true,
          example: "1"
        )

        vehicle_class(
          :string,
          "Vehicle Class\nWhen not set `vehicle_class` will be calculated from the volume of the Match's items. Required if automatic vehicle selection is not enabled.",
          example: 2
        )

        shipper_email(
          :string,
          "Shipper Email\nOnly provide this if you want to place orders under another shipper account on your company other than the default.",
          example: "shipper@example.com"
        )

        has_load_fee(
          :boolean,
          "Has load fee\nSet to `true` if Driver will have to load or unload more than 200lbs of cargo"
        )

        pickup_notes(:string, "Pickup Notes")
        delivery_notes(:string, "Dropoff Notes")
        po(:string, "PO/Job Number")
        recipient_name(:string, "Recipient Name", example: "John Smith")
        recipient_phone(:string, "Recipient Phone", example: "1234567890")
        recipient_email(:string, "Recipient Email", example: "jsmith@example.com")

        notify_recipient(
          :boolean,
          "Notify Recipient\nWhen `true`, recipient will recieve notifications from Frayt regarding the status of this Match"
        )

        pickup_at(:string, "Scheduled Pick up Date/Time (ISO format)", example: "2020-09-28T09:31")

        dropoff_at(:string, "Scheduled Drop off Date/Time (ISO format)",
          example: "2020-09-28T18:31"
        )

        tip(:integer, "Tip\nAdditional pay for driver in US cents")

        identifier(
          :string,
          "Identifier\nOptional unique identifier from external system. This will be sent back in webhooks."
        )

        contract(:string, "Contract")
      end
    end
  end

  def schema(:Matches, _) do
    swagger_schema do
      title("Matches")
      description("A collection of matches that belong to a Batch")
      type(:array)
      items(Schema.ref(:Match))
      min_items(1)
    end
  end

  def schema(:MatchStopItem, _) do
    swagger_schema do
      title("Match Stop Item")
      description("An item that belongs to a Match")

      properties do
        description(:string, "Description of the item", required: true, example: "Car Tire")
        length(:integer, "Individual item length in inches", minimum: 0, example: 8)
        width(:integer, "Individual item width in inches", minimum: 0, example: 24)
        height(:integer, "Individual item height in inches", minimum: 0, example: 24)

        weight(:integer, "Individual item weight in pounds",
          required: true,
          minimum: 0,
          example: 80
        )

        volume(
          :integer,
          "Individual item volume in cubic inches. Will be used to calculate total volume in place of dimensions when provided. Required when width, length or height are not provided.",
          minimum: 0,
          example: nil
        )

        pieces(:integer, "Quantity of these items", required: true, minimum: 1, example: 4)
      end
    end
  end

  def schema(:MatchStopItems, _) do
    swagger_schema do
      title("Match Stop Items")
      description("A collection if items that belongs to a Match")
      type(:array)
      items(Schema.ref(:MatchStopItem))
      min_items(1)
    end
  end

  def schema(:MatchStop, _) do
    swagger_schema do
      title("Match Stop")
      description("A stop that belongs to a Match")

      properties do
        items(Schema.ref(:MatchStopItems), "Items", required: true)

        notify_recipient(
          :boolean,
          "Notify Recipient\nWhen `true`, recipient will recieve notifications from Frayt regarding the status of this Match"
        )

        destination_address(:string, "Destination Address",
          required: true,
          example: "1241 Elm St, Cincinnati, OH 45202"
        )

        delivery_notes(:string, "Dropoff Notes")
        po(:string, "PO/Job Number")
        recipient_name(:string, "Recipient Name", example: "John Smith")
        recipient_phone(:string, "Recipient Phone", example: "1234567890")
        recipient_email(:string, "Recipient Email", example: "jsmith@example.com")

        dropoff_at(:string, "Scheduled Drop off Date/Time (ISO format)",
          example: "2020-09-28T18:31"
        )

        tip(:integer, "Tip\nAdditional pay for driver in US cents")

        has_load_fee(
          :boolean,
          "Has load fee\nSet to `true` if Driver will have to load or unload more than 200lbs of cargo"
        )
      end
    end
  end

  def schema(:MatchStops, _) do
    swagger_schema do
      title("Match Stop")
      description("A collection of stops that belong to a Match")
      type(:array)
      items(Schema.ref(:MatchStop))
      min_items(1)
    end
  end

  def schema(:Batch, _) do
    swagger_schema do
      title("Batch")
      description("A collection of Matches that belong to a Delivery Batch")

      properties do
        pickup_at(:string, "Scheduled Pick up Date/Time (ISO format)", example: "2020-09-28T09:31")

        identifier(
          :string,
          "Identifier\nOptional unique identifier from external system. This will be sent back in webhooks."
        )

        contract(:string, "Contract")

        origin_address(:string, "Origin Address",
          required: true,
          example: "1311 Vine St. Cincinnati, OH 45202"
        )

        shipper_email(
          :string,
          "Shipper Email\nOnly provide this if you want to place orders under another shipper account on your company other than the default.",
          example: "shipper@example.com"
        )

        pickup_notes(:string, "Pickup Notes")

        po(:string, "PO/Job Number")

        stops(Schema.ref(:MatchStops), "Stops", required: true)

        matches(Schema.ref(:Matches))
      end
    end
  end
end
