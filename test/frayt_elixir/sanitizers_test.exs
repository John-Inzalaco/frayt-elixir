defmodule FraytElixir.SanitizersTest do
  use FraytElixir.DataCase

  import FraytElixir.Sanitizers

  alias FraytElixir.Accounts.{Shipper, User}

  describe "strip_nondigits" do
    test "strip_nondigits with formatted number" do
      %Ecto.Changeset{changes: changes} =
        Shipper.changeset(%Shipper{}, %{phone: "(555) 555 - 5555"}) |> strip_nondigits(:phone)

      assert changes.phone == "5555555555"
    end

    test "strip_nondigits with unformatted number" do
      %Ecto.Changeset{changes: changes} =
        Shipper.changeset(%Shipper{}, %{phone: "5555555555"}) |> strip_nondigits(:phone)

      assert changes.phone == "5555555555"
    end

    test "strip_nondigits with nil" do
      %Ecto.Changeset{changes: changes} =
        Shipper.changeset(%Shipper{}, %{phone: nil}) |> strip_nondigits(:phone)

      refute Map.has_key?(changes, :phone)
    end

    test "strip_nondigits with empty string" do
      %Ecto.Changeset{changes: changes} =
        Shipper.changeset(%Shipper{}, %{phone: ""}) |> strip_nondigits(:phone)

      refute Map.has_key?(changes, :phone)
    end
  end

  describe "convert_to_lowercase" do
    test "with mixed case string" do
      %Ecto.Changeset{changes: changes} =
        User.changeset(%User{}, %{email: "JOHN@Doe.cOM"}) |> convert_to_lowercase(:email)

      assert changes.email == "john@doe.com"
    end

    test "with lowercase string" do
      %Ecto.Changeset{changes: changes} =
        User.changeset(%User{}, %{email: "john@doe.com"}) |> convert_to_lowercase(:email)

      assert changes.email == "john@doe.com"
    end

    test "with nil" do
      %Ecto.Changeset{changes: changes} =
        User.changeset(%User{}, %{email: nil}) |> convert_to_lowercase(:email)

      refute Map.has_key?(changes, :email)
    end
  end
end
