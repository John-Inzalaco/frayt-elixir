defmodule FraytElixir.EquationsTest do
  use FraytElixir.DataCase
  import Ecto.Changeset
  alias Ecto.Changeset
  alias FraytElixir.Equations

  defmodule Calculator do
    use Ecto.Schema

    embedded_schema do
      field :equation, :string
    end

    def changeset(equation) do
      %__MODULE__{}
      |> cast(%{equation: equation}, [:equation])
    end
  end

  describe "validate_equation" do
    @allowed_vars ~w(travel_duration total_distance stop_count)
    test "validates a valid equation" do
      assert %Changeset{valid?: true} =
               Calculator.changeset("travel_duration + total_distance + stop_count")
               |> Equations.validate_equation(:equation, @allowed_vars)

      assert %Changeset{valid?: true} =
               Calculator.changeset("travel_duration - total_distance/stop_count")
               |> Equations.validate_equation(:equation, @allowed_vars)

      assert %Changeset{valid?: true} =
               Calculator.changeset("travel_duration+total_distance*stop_count")
               |> Equations.validate_equation(:equation, @allowed_vars)

      assert %Changeset{valid?: true} =
               Calculator.changeset("travel_duration/total_distance*stop_count")
               |> Equations.validate_equation(:equation, @allowed_vars)
    end

    test "allows built in functions" do
      equation =
        "sin(total_distance) + cos(total_distance) + tan(total_distance) - floor(travel_duration) + ceil(travel_duration) + round(stop_count)"

      assert %Changeset{valid?: true} =
               Calculator.changeset(equation)
               |> Equations.validate_equation(:equation, @allowed_vars)
    end

    test "returns error for invalid variables" do
      assert %Changeset{
               valid?: false,
               errors: [
                 equation: {"foo and bar are not allowed variables", [validation: :equation]}
               ]
             } =
               Calculator.changeset("foo + bar")
               |> Equations.validate_equation(:equation, @allowed_vars)

      assert %Changeset{
               valid?: false,
               errors: [
                 equation: {"x is not an allowed variable", [validation: :equation]}
               ]
             } =
               Calculator.changeset("travel_duration + x")
               |> Equations.validate_equation(:equation, @allowed_vars)
    end

    test "returns error for invalid syntax" do
      assert %Changeset{
               valid?: false,
               errors: [
                 equation: {"syntax error before: ''<='' on line 1", [validation: :equation]}
               ]
             } =
               Calculator.changeset("<=1")
               |> Equations.validate_equation(:equation, @allowed_vars)

      assert %Changeset{
               valid?: false,
               errors: [
                 equation: {"syntax error at end of line on line 1", [validation: :equation]}
               ]
             } =
               Calculator.changeset("1<=")
               |> Equations.validate_equation(:equation, @allowed_vars)

      assert %Changeset{
               valid?: false,
               errors: [
                 equation:
                   {"has invalid syntax. This may be due to an incomplete decimal",
                    [validation: :equation]}
               ]
             } =
               Calculator.changeset("2 * 1.")
               |> Equations.validate_equation(:equation, @allowed_vars)

      assert %Changeset{
               valid?: false,
               errors: [
                 equation: {"invalid term '=2' on line 1", [validation: :equation]}
               ]
             } =
               Calculator.changeset("1=2")
               |> Equations.validate_equation(:equation, @allowed_vars)
    end
  end
end
