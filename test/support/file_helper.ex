defmodule FraytElixirWeb.Test.FileHelper do
  def base64_image() do
    binary_image() |> Base.encode64()
  end

  def binary_image do
    "#{__DIR__}/../fixtures/assets/image.png"
    |> File.read!()
  end

  def base64_image(_), do: {:ok, image: base64_image()}

  def image_path, do: "#{__DIR__}/../fixtures/assets/image.png"
end
