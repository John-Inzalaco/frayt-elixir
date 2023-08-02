defmodule FraytElixirWeb.UploadHelperTest do
  use FraytElixir.DataCase

  alias FraytElixirWeb.Test.FileHelper

  import FraytElixirWeb.UploadHelper

  describe "file_from_base64/2" do
    test "returns a file" do
      image = FileHelper.base64_image()

      assert {:ok,
              %{
                filename: "profile_photo.jpg",
                binary: _binary
              }} = file_from_base64(image, "adfasfda.jpg", :profile_photo)
    end

    test "fails with nothing sent" do
      assert {:error, "No file uploaded"} =
               file_from_base64(nil, "profile_photo.jpg", :profile_photo)
    end

    test "fails with invalid base64" do
      assert {:error, :invalid_file} =
               file_from_base64("garbage", "profile_photo.jpg", :profile_photo)
    end
  end

  describe "file_from_path/2" do
    test "returns a file" do
      assert {:ok,
              %{
                filename: "profile_photo.png",
                binary: "" <> _
              }} = file_from_path(FileHelper.image_path(), "profile_photo.png", :profile_photo)
    end

    test "fails with invalid file path" do
      assert {:error, :invalid_file} = file_from_path("garbage", "garbage.png", :profile_photo)
    end
  end
end
