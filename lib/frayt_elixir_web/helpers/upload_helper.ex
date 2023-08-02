defmodule FraytElixirWeb.UploadHelper do
  def file_from_base64(base64_file, _filename, _key) when is_nil(base64_file),
    do: {:error, "No file uploaded"}

  def file_from_base64(base64_file, filename, key) do
    case Base.decode64(base64_file) do
      :error ->
        {:error, :invalid_file}

      {:ok, binary} ->
        file_from_binary(binary, filename, key)
    end
  end

  def file_from_path(path, filename, key) do
    case File.read(path) do
      {:ok, binary} -> file_from_binary(binary, filename, key)
      _ -> {:error, :invalid_file}
    end
  end

  def file_from_binary(binary, filename, key) do
    {:ok,
     %{
       filename: "#{key}" <> Path.extname(filename),
       binary: binary
     }}
  end
end
