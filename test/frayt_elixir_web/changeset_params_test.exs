defmodule FraytElixirWeb.ChangesetParamsTest do
  use Params
  use FraytElixir.DataCase
  alias FraytElixirWeb.ChangesetParams
  alias Ecto.Changeset

  defparams(
    user_params(%{
      email!: :string,
      name: :string,
      roles: [%{name: :string}],
      vehicle: %{
        name: :string,
        company: %{
          name: :string
        }
      }
    })
  )

  describe "get_data/1" do
    test "returns valid data" do
      assert {:ok, %{email: "joe"}} =
               %{"email" => "joe"} |> user_params() |> ChangesetParams.get_data()
    end

    test "returns nested map" do
      assert {:ok, %{email: "joe", vehicle: %{name: "Model 3", company: %{name: "tesla"}}}} =
               %{
                 "email" => "joe",
                 "vehicle" => %{"name" => "Model 3", "company" => %{"name" => "tesla"}}
               }
               |> user_params()
               |> ChangesetParams.get_data()
    end

    test "returns nested array" do
      assert {:ok, %{email: "joe", roles: [%{name: "Admin"}]}} =
               %{"email" => "joe", "roles" => [%{"name" => "Admin"}]}
               |> user_params()
               |> ChangesetParams.get_data()
    end

    test "ignores invalid keys" do
      assert {:ok, %{email: "joe"}} =
               %{"email" => "joe", "bob" => "jones"}
               |> user_params()
               |> ChangesetParams.get_data()
    end

    test "returns error on invalid changeset" do
      assert {:error, %Changeset{}} = %{} |> user_params() |> ChangesetParams.get_data()
    end
  end
end
