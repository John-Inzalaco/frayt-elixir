defmodule FraytElixir.Photo do
  use Waffle.Definition
  use Waffle.Ecto.Definition
  alias FraytElixir.Drivers.{VehicleDocument, DriverDocument}
  alias FraytElixirWeb.Router.Helpers, as: Routes

  # Include ecto support (requires package arc_ecto installed):
  # use AWafflerc.Ecto.Definition

  @versions [:original]

  # To add a thumbnail version:
  # @versions [:original, :thumb]

  # Override the bucket on a per definition basis:
  # def bucket do
  #   :custom_bucket_name
  # end

  # Whitelist file extensions:
  # def validate({file, _}) do
  #   ~w(.jpg .jpeg .gif .png) |> Enum.member?(Path.extname(file.file_name))
  # end

  # Define a thumbnail transformation:
  # def transform(:thumb, _) do
  #   {:convert, "-strip -thumbnail 250x250^ -gravity center -extent 250x250 -format png", :png}
  # end

  # Override the persisted filenames:
  # def filename(version, _) do
  #   version
  # end

  @photo_url_generator Application.compile_env(
                         :frayt_elixir,
                         :photo_url_generator,
                         &FraytElixir.Photo.s3_presigned_url/1
                       )

  # Override the storage directory:
  def storage_dir(_version, {_file, %VehicleDocument{vehicle_id: vehicle_id}}),
    do: get_storage_path(vehicle_id)

  def storage_dir(_version, {_file, %DriverDocument{driver_id: driver_id}}),
    do: get_storage_path(driver_id)

  def storage_dir(_version, {_file, scope}), do: get_storage_path(scope.id)

  # Provide a default URL if there hasn't been a file uploaded
  # def default_url(version, scope) do
  #   "/images/avatars/default_#{version}.png"
  # end

  # Specify custom headers for s3 objects
  # Available options are [:cache_control, :content_disposition,
  #    :content_encoding, :content_length, :content_type,
  #    :expect, :expires, :storage_class, :website_redirect_location]
  #
  # def s3_object_headers(version, {file, scope}) do
  #   [content_type: MIME.from_path(file.file_name)]
  # end

  def get_storage_path(scope_id) do
    "/uploads/#{scope_id}"
  end

  def get_storage_path(scope_id, file_name) do
    dir = get_storage_path(scope_id)

    "#{dir}/#{file_name}"
  end

  def get_url(id, file) when is_binary(file) do
    id
    |> get_storage_path(file)
    |> @photo_url_generator.()
  end

  def get_url(id, %{file_name: file_name}) do
    id
    |> get_storage_path(file_name)
    |> @photo_url_generator.()
  end

  def get_url(id, %{document: %{file_name: file_name}}) do
    id
    |> get_storage_path(file_name)
    |> @photo_url_generator.()
  end

  def get_url(_id, _), do: {:error, :not_found}

  def local_storage_url(path) do
    {:ok, Routes.static_url(FraytElixirWeb.Endpoint, path)}
  end

  def s3_presigned_url(path) do
    bucket = Application.get_env(:waffle, :bucket)

    ExAws.Config.new(:s3)
    |> ExAws.S3.presigned_url(:get, bucket, path, expires_in: 60 * 60 * 24)
  end
end
