defmodule FraytElixir.Shipment.BarcodeReadingsTest do
  use FraytElixir.DataCase
  alias FraytElixir.Shipment.BarcodeReadings
  alias FraytElixirWeb.Test.FileHelper

  @valid_attrs %{
    photo: nil,
    type: :pickup,
    state: :captured,
    match_stop_item_id: nil,
    barcode: "123barcode456"
  }

  describe "create/2" do
    test "barcode success with valid attrs" do
      item = insert(:match_stop_item_with_barcode)

      assert {:ok, _} = BarcodeReadings.create(item, @valid_attrs)
    end

    test "barcode fails with invalid attrs" do
      item = insert(:match_stop_item_with_barcode)
      assert {:error, _} = BarcodeReadings.create(item, %{})
    end

    test "does not allow multiples pickup/delivery for same item" do
      item = insert(:match_stop_item_with_barcode)

      assert {:ok, _} = BarcodeReadings.create(item, @valid_attrs)
      assert {:error, _} = BarcodeReadings.create(item, @valid_attrs)

      valid_attrs = %{@valid_attrs | type: :delivery}
      assert {:ok, _} = BarcodeReadings.create(item, valid_attrs)
      assert {:error, _} = BarcodeReadings.create(item, valid_attrs)
    end

    test "creates missing barcode" do
      item = insert(:match_stop_item_with_barcode)

      attrs = %{
        @valid_attrs
        | state: "missing",
          photo: FileHelper.base64_image()
      }

      assert {:ok, _} = BarcodeReadings.create(item, attrs)

      attrs = %{
        attrs
        | type: :delivery,
          photo: %{filename: "photo.jpg", binary: FileHelper.binary_image()}
      }

      assert {:ok, _} = BarcodeReadings.create(item, attrs)
    end

    test "photo is required when state is equal to missing" do
      item = insert(:match_stop_item_with_barcode)

      attrs = %{@valid_attrs | state: "missing"}
      assert {:error, _} = BarcodeReadings.create(item, attrs)
    end

    test "fails when barcode readed do not matches the barcode stored" do
      item = insert(:match_stop_item_with_barcode)

      valid_attrs = %{@valid_attrs | barcode: "doesn't_match"}
      assert {:error, _} = BarcodeReadings.create(item, valid_attrs)
    end

    test "when a barcode is not specified it should allow any value for the barcode" do
      item = insert(:match_stop_item)

      valid_attrs = %{@valid_attrs | barcode: "it's_empty"}
      assert {:ok, cs} = BarcodeReadings.create(item, valid_attrs)
      assert %{barcode: "it's_empty"} = cs
    end

    test "fails when missing barcode " do
      item = insert(:match_stop_item)

      attrs = %{@valid_attrs | barcode: nil}
      assert {:error, _} = BarcodeReadings.create(item, attrs)
    end
  end
end
