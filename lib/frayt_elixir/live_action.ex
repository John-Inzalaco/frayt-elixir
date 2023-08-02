defmodule FraytElixir.LiveAction do
  import Phoenix.LiveView
  alias Phoenix.LiveView.Socket
  alias FraytElixir.LiveAction
  defstruct active?: false, error?: false, result: nil

  def new do
    %__MODULE__{}
  end

  @type action() :: (() -> {:error, any()} | {:ok, any()})

  @spec start(Socket.t(), atom(), action()) :: Socket.t()
  def start(socket, key, action) do
    %LiveAction{} = live_action = Map.get(socket.assigns, key)

    socket = assign(socket, key, %LiveAction{live_action | active?: true, error?: false})

    send(socket.root_pid, {:live_action, key, action})

    socket
  end

  def error?(%LiveAction{error?: error}), do: error
  def active?(%LiveAction{active?: active}), do: active

  def render_result(%LiveAction{result: result}) when is_binary(result), do: result
  def render_result(%LiveAction{result: result}), do: inspect(result)

  def handle_live_action(key, action, socket) do
    socket =
      case action.() do
        {code, result, socket = %Phoenix.LiveView.Socket{}} ->
          assign_result(socket, key, {code, result})

        {code, _status_code, result} ->
          assign_result(socket, key, {code, result})

        output ->
          assign_result(socket, key, output)
      end

    {:noreply, socket}
  end

  defp assign_result(socket, key, {code, result}) do
    %__MODULE__{} = live_action = Map.get(socket.assigns, key)

    assign(socket, key, %LiveAction{
      live_action
      | active?: false,
        result: result,
        error?: code == :error
    })
  end

  defmacro __using__(_) do
    quote do
      def handle_info({:live_action, key, action}, socket) do
        LiveAction.handle_live_action(key, action, socket)
      end
    end
  end
end
