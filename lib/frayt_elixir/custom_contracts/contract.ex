defmodule FraytElixir.CustomContracts.Contract do
  alias FraytElixir.CustomContracts.Contract
  alias FraytElixir.Shipment.Match
  alias FraytElixir.Validators
  alias Ecto.Changeset

  @type option :: {:update_tolls, keyword(Type.t())}
  @callback calculate_pricing(match :: Match.t()) :: Changeset.t()

  defmacro __using__(_) do
    quote do
      @behaviour Contract
      @type email_list() :: list({String.t(), String.t()} | String.t())

      def get_auto_configure_dropoff_at, do: {:ok, false}

      def get_auto_dropoff_at_time, do: nil

      def get_auto_cancel_on_driver_cancel_time_after_acceptance, do: nil

      def get_auto_cancel_on_driver_cancel, do: nil

      def get_auto_cancel_time, do: nil

      defp validate_single_stop(changeset),
        do:
          changeset
          |> Validators.validate_assoc_length(:match_stops,
            max: 1,
            message:
              "length is limited to %{count} since this contract does not support multiple stops"
          )

      @spec include_tolls?(match :: Match.t()) :: boolean()
      def include_tolls?(_match), do: false

      defoverridable get_auto_configure_dropoff_at: 0
      defoverridable get_auto_dropoff_at_time: 0
      defoverridable get_auto_cancel_on_driver_cancel_time_after_acceptance: 0
      defoverridable get_auto_cancel_on_driver_cancel: 0
      defoverridable get_auto_cancel_time: 0
      defoverridable include_tolls?: 1
    end
  end
end
