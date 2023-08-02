defmodule FraytElixirWeb.UserSocket do
  use Phoenix.Socket

  ## Channels
  channel "driver_locations:*", FraytElixirWeb.DriverLocationsChannel

  # Socket params are passed from the client and can
  # be used to verify and authenticate a user. After
  # verification, you can put default assigns into
  # the socket that will be set for all channels, ie
  #
  #     {:ok, assign(socket, :user_id, verified_user_id)}
  #
  # To deny connection, return `:error`.
  #
  # See `Phoenix.Token` documentation for examples in
  # performing token verification on connect.
  def connect(_params, socket, _connect_info) do
    {:ok, socket}
  end

  # Socket id's are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "user_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     FraytElixirWeb.Endpoint.broadcast("user_socket:#{user.id}", "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
  def id(_socket), do: nil

  defmodule Serializer do
    alias Phoenix.Socket.Broadcast
    alias Phoenix.Socket.V2.JSONSerializer
    alias FraytElixir.Drivers.DriverLocation
    @behaviour Phoenix.Socket.Serializer

    def encode!(%{payload: %DriverLocation{} = dl} = rep_or_msg) do
      payload = convert_to_json(dl)

      encode!(%{rep_or_msg | payload: payload})
    end

    def encode!(rep_or_msg), do: JSONSerializer.encode!(rep_or_msg)

    def fastlane!(%Broadcast{payload: %DriverLocation{} = dl} = broadcast) do
      payload = convert_to_json(dl)

      fastlane!(%{broadcast | payload: payload})
    end

    def fastlane!(broadcast), do: JSONSerializer.fastlane!(broadcast)

    defdelegate decode!(iodata, options), to: JSONSerializer

    defp convert_to_json(%DriverLocation{} = dl) do
      FraytElixirWeb.DriverLocationView.render("driver_location.json", driver_location: dl)
    end
  end
end
