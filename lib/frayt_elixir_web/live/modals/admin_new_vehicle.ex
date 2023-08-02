defmodule FraytElixirWeb.AdminNewVehicle do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_event("close_modal", _event, socket) do
    send(socket.parent_pid, :close_modal)
    {:noreply, socket}
  end

  def render(assigns) do
    ~L"""
    <form>
      <section>
        <div>
          <label class="label">Make</label>
          <input class="input"></input>
        </div>
        <div>
          <label class="label">Model</label>
          <input class="input"></input>
        </div>
        <div>
          <label class="label">Year</label>
          <input class="input"></input>
        </div>
        <div>
          <label class="label">License Plate</label>
          <input class="input"></input>
        </div>
        <div>
          <label class="label">VIN #</label>
          <input class="input"></input>
        </div>
        <div>
          <label class="label">Vehicle Registration</label>
          <input class="input"></input>
        </div>
        <div class="width--half">
          <div>
            <label class="label">Vehicle Insurance</label>
            <input class="input"></input>
          </div>
          <div>
            <label class="label">Type</label>
            <select class="select">
              <option>Car</option>
              <option>Midsize</option>
              <option>Cargo Van</option>
            </select>
          </div>
          <div>
            <label class="label">Vehicle Photo</label>
            <div>
              <i class="material-icons icon">add_circle_outline</i>
              <p>Add Vehicle Photo(s)</p>
            </div>
          </div>
        </div>
        <div>
          <label class="label">Max Cargo Weight</label>
          <input class="input"></input>
        </div>
        <div>
          <label class="label">Length</label>
          <div>
            <i class="material-icons icon">add_circle_outline</i>
            <p>Add License Photo</p>
          </div>
        </div>
        <div>
          <label class="label">Wheel Well Distance</label>
          <input class="input"></input>
        </div>
        <div>
          <label class="label">Width</label>
          <input class="input"></input>
        </div>
        <div>
          <label class="label">Height</label>
          <input class="input"></input>
        </div>
        <div>
          <label class="label">Door Width</label>
          <input class="input"></input>
        </div>
        <div>
          <label class="label">Door Height</label>
          <input class="input"></input>
        </div>
        <div>
          <a onclick="" href="#" class="link">+ Add Vehicle</a>
        </div>
        <div class="width--full">
          <button class="button button--primary" tabindex=0 phx-keyup="close_modal" phx-key="Enter" phx-click="close_modal">Next</button>
          <a onclick="" class="button" phx-click="close_modal">Cancel</a>
        </div>
      </section>
    </form>
    """
  end
end
