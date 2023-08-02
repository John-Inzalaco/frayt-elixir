defmodule FraytElixir.ChangesetHelpersTest do
  use FraytElixir.DataCase

  alias Ecto.Changeset
  alias FraytElixir.ChangesetHelpers

  describe "cast_from_form" do
    test "casts arrays" do
      data = %{strings: ["c"]}
      types = %{strings: {:array, :string}}
      attrs = %{"strings" => ["a", "b"]}

      changeset =
        {data, types}
        |> Changeset.cast(attrs, [])
        |> ChangesetHelpers.cast_from_form(attrs, [:strings])

      assert changeset.changes == %{strings: ["a", "b"]}
    end

    test "casts arrays and filters empty values" do
      data = %{strings: ["c"]}
      types = %{strings: {:array, :string}}
      attrs = %{"strings" => ["a", "b", ""]}

      changeset =
        {data, types}
        |> Changeset.cast(attrs, [])
        |> ChangesetHelpers.cast_from_form(attrs, [:strings])

      assert changeset.changes == %{strings: ["a", "b"]}
    end

    test "allows overriding empty_values" do
      data = %{strings: ["c"]}
      types = %{strings: {:array, :string}}
      attrs = %{"strings" => ["a", "b", "[]", ""]}

      changeset =
        {data, types}
        |> Changeset.cast(attrs, [])
        |> ChangesetHelpers.cast_from_form(attrs, [:strings], empty_values: ["[]"])

      assert changeset.changes == %{strings: ["a", "b", ""]}
    end

    test "ignores fields when no params are provided" do
      data = %{strings: ["c"]}
      types = %{strings: {:array, :string}}

      changeset =
        {data, types}
        |> Changeset.cast(%{}, [])
        |> ChangesetHelpers.cast_from_form(%{}, [:strings])

      assert changeset.changes == %{}
    end
  end
end
