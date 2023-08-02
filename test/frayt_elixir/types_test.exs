defmodule FraytElixir.TypesTest do
  use FraytElixir.DataCase
  alias FraytElixir.Drivers.Driver
  alias FraytElixir.Repo
  alias Ecto.Changeset
  import FraytElixir.Validators
  alias ExPhoneNumber.Model.PhoneNumber

  describe "PhoneNumber" do
    test "casts valid phone number with hyphens" do
      assert %Changeset{
               valid?: true,
               changes: %{
                 phone_number: %PhoneNumber{country_code: 1, national_number: 9_372_057_050}
               }
             } =
               %Driver{}
               |> Changeset.cast(%{phone_number: "+1937-205-7050"}, [:phone_number])

      assert %Changeset{
               valid?: true,
               changes: %{
                 phone_number: %PhoneNumber{country_code: 1, national_number: 9_372_057_050}
               }
             } =
               %Driver{}
               |> Changeset.cast(%{phone_number: "+1 937-205-7050"}, [:phone_number])
    end

    test "casts valid phone number from e164" do
      assert %Changeset{
               valid?: true,
               changes: %{
                 phone_number: %PhoneNumber{country_code: 1, national_number: 9_372_057_050}
               }
             } =
               %Driver{}
               |> Changeset.cast(%{phone_number: "+19372057050"}, [:phone_number])
    end

    test "attempts to cast phone number with missing country code to US" do
      assert %Changeset{
               valid?: true,
               changes: %{
                 phone_number: %PhoneNumber{country_code: 1, national_number: 9_372_057_050}
               }
             } =
               %Driver{}
               |> Changeset.cast(%{phone_number: "9372057050"}, [:phone_number])
    end

    test "casts PhoneNumber" do
      {:ok, phone_number} = ExPhoneNumber.parse("+19372057050", "")

      assert %Changeset{
               valid?: true,
               changes: %{
                 phone_number: %PhoneNumber{country_code: 1, national_number: 9_372_057_050}
               }
             } =
               %Driver{}
               |> Changeset.cast(%{phone_number: phone_number}, [
                 :phone_number
               ])
    end

    test "does not cast when empty string" do
      assert %Changeset{
               valid?: true,
               changes: changes
             } =
               %Driver{}
               |> Changeset.cast(%{phone_number: ""}, [:phone_number])

      refute changes[:phone_number]
    end

    test "returns cast error for invalid number" do
      assert %Changeset{
               valid?: false,
               errors: [
                 phone_number:
                   {"Invalid country calling code",
                    [type: FraytElixir.Type.PhoneNumber, validation: :cast]}
               ]
             } =
               %Driver{}
               |> Changeset.cast(%{phone_number: "1234567"}, [:phone_number])
    end

    test "returns cast error for invalid country code" do
      assert %Changeset{
               valid?: false,
               errors: [
                 phone_number:
                   {"Invalid country calling code",
                    [type: FraytElixir.Type.PhoneNumber, validation: :cast]}
               ]
             } =
               %Driver{}
               |> Changeset.cast(%{phone_number: "12349372057059"}, [:phone_number])
    end

    test "returns cast error for invalid regional number" do
      assert %Changeset{
               valid?: false,
               errors: [
                 phone_number:
                   {"The string supplied did not seem to be a valid phone number",
                    [validation: :phone_number]}
               ]
             } =
               %Driver{}
               |> Changeset.cast(%{phone_number: "+19370000000"}, [:phone_number])
               |> validate_phone_number(:phone_number)
    end

    test "returns cast error for gibberish" do
      assert %Changeset{
               valid?: false,
               errors: [
                 phone_number:
                   {"The string supplied did not seem to be a phone number",
                    [type: FraytElixir.Type.PhoneNumber, validation: :cast]}
               ]
             } =
               %Driver{}
               |> Changeset.cast(%{phone_number: "qwerty"}, [:phone_number])
    end

    test "saves to the database" do
      assert {:ok,
              %Driver{phone_number: %PhoneNumber{country_code: 1, national_number: 9_372_057_050}}} =
               %Driver{}
               |> Changeset.cast(%{phone_number: "+19372057050"}, [:phone_number])
               |> Repo.insert()
    end

    test "loads from the database" do
      driver = insert(:driver, phone_number: "+19372057050")

      %Driver{phone_number: %PhoneNumber{country_code: 1, national_number: 9_372_057_050}} =
        Repo.get!(Driver, driver.id)
    end

    test "handles invalid phone numbers when loading" do
      driver = insert(:driver)
      {:ok, driver_id} = Ecto.UUID.dump(driver.id)

      assert {1, nil} =
               from("drivers",
                 where: [id: ^driver_id],
                 update: [set: [phone_number: "123456"]]
               )
               |> Repo.update_all([])

      %Driver{phone_number: nil} = Repo.get!(Driver, driver.id)
    end

    test "handles no phone number when loading" do
      driver = insert(:driver, phone_number: nil)
      %Driver{phone_number: nil} = Repo.get!(Driver, driver.id)
    end
  end
end
