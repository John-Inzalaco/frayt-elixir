defmodule FraytElixir.DriverDocuments do
  import Ecto.Query, warn: false

  alias Ecto.UUID
  alias Ecto.Multi
  alias FraytElixir.Repo
  alias FraytElixir.Photo

  alias FraytElixir.Drivers.{
    Driver,
    VehicleDocument,
    DriverDocument,
    VehicleDocumentType
  }

  alias FraytElixir.Notifications.DriverNotification

  def latest_vehicle_documents_query do
    from(
      d in subquery(
        from(d0 in VehicleDocument,
          order_by: [desc: d0.inserted_at],
          distinct: [d0.type, d0.vehicle_id]
        )
      )
    )
  end

  def latest_driver_documents_query do
    from(
      d in subquery(
        from(d0 in DriverDocument,
          order_by: [desc: d0.inserted_at],
          distinct: [d0.type, d0.driver_id]
        )
      )
    )
  end

  def validate_driver_documents(driver) do
    documents =
      Enum.flat_map(driver.vehicles, & &1.images)
      |> Enum.concat(driver.images)
      |> Enum.reduce(%{}, &Map.put(&2, &1.type, &1))

    vehicle_doc_types = VehicleDocumentType.all_types() -- [:carrier_agreement, :vehicle_type]

    doc_types = [:license | vehicle_doc_types]

    case invalid_documents_count(documents, doc_types) do
      [] -> :ok
      invalid_counts -> {:error, invalid_counts}
    end
  end

  defp invalid_documents_count(documents, doc_types) do
    Enum.reduce(doc_types, [], fn doc_type, acc ->
      doc = Map.get(documents, doc_type)
      now = Date.utc_today()

      key =
        cond do
          is_nil(doc) -> :missing
          doc.state in [:pending_approval, :rejected] -> doc.state
          is_nil(doc.expires_at) -> nil
          Date.compare(doc.expires_at, now) == :lt -> :expired
          true -> nil
        end

      if key, do: Keyword.put(acc, key, (acc[key] || 0) + 1), else: acc
    end)
  end

  def change_driver_documents(driver, attrs \\ %{}) do
    Driver.document_changeset(driver, attrs)
  end

  def review_driver_documents(driver, attrs) do
    changeset = Driver.document_changeset(driver, attrs)

    with {:ok, driver} <- Repo.update(changeset) do
      images = driver.images ++ List.first(driver.vehicles).images

      if Enum.all?(images, &(&1.state == :approved)) do
        DriverNotification.send_documents_approved(driver)
        DriverNotification.send_approved_documents_email(driver)
      else
        DriverNotification.send_documents_rejected(driver)
        DriverNotification.send_rejected_documents_email(driver)
      end

      {:ok, driver}
    end
  end

  def get_latest_driver_document(driver_id, type) do
    qry =
      from m in DriverDocument,
        where: m.driver_id == ^driver_id and m.type == ^type,
        order_by: [desc: m.inserted_at],
        limit: 1

    Repo.one(qry)
  end

  def get_latest_vehicle_document(vehicle_id, type) do
    from(v in VehicleDocument,
      where: v.vehicle_id == ^vehicle_id and v.type == ^type,
      order_by: [desc: :inserted_at],
      distinct: v.type
    )
    |> Repo.one()
  end

  def get_vehicle_document(id) do
    from(v in VehicleDocument, where: v.id == ^id)
    |> Repo.one()
  end

  def create_driver_document(attrs) do
    document = parse_document(attrs.document, attrs.type)

    %DriverDocument{}
    |> DriverDocument.changeset(%{attrs | document: document})
    |> Repo.insert()
  end

  def create_vehicle_document(attrs) do
    document = parse_document(attrs.document, attrs.type)

    %VehicleDocument{}
    |> VehicleDocument.changeset(%{attrs | document: document})
    |> Repo.insert()
  end

  defp parse_document(document, type) do
    case document do
      %{data: data} ->
        %{filename: "#{type}-#{UUID.generate()}.jpeg", binary: Base.decode64!(data)}

      %{binary: binary} ->
        %{filename: "#{type}-#{UUID.generate()}.jpeg", binary: binary}

      %{path: path} ->
        %{filename: "#{type}-#{UUID.generate()}.jpeg", binary: File.read!(path)}

      document ->
        document
    end
  end

  def update_vehicle_documents(documents) when is_list(documents) do
    document_changesets = prepare_changesets(documents)

    Enum.reduce(document_changesets, Multi.new(), fn cs, multi ->
      %{data: %{id: doc_id}} = cs
      Multi.update(multi, {:document, doc_id}, cs)
    end)
    |> Repo.transaction()
  end

  def update_vehicle_documents(documents) do
    document_changeset = prepare_changesets(documents)

    Repo.update(%VehicleDocument{}, document_changeset)
  end

  defp prepare_changesets(documents) when is_list(documents) do
    Enum.map(documents, &prepare_changesets(&1))
  end

  defp prepare_changesets(document) do
    case get_vehicle_document(document.id) do
      nil ->
        %VehicleDocument{}
        |> VehicleDocument.changeset(document)

      %VehicleDocument{} = orig ->
        VehicleDocument.changeset(orig, document)
    end
  end

  def get_s3_asset(:profile_photo, %Driver{id: driver_id}) do
    profile_photo =
      from(dd in DriverDocument,
        where: dd.driver_id == ^driver_id and dd.type == "profile",
        order_by: [desc: :inserted_at],
        distinct: dd.type
      )
      |> Repo.one()

    Photo.get_url(driver_id, profile_photo)
  end

  def get_s3_asset(_, _), do: {:error, "That is not a thing."}
end
