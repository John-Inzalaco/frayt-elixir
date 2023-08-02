defmodule FraytElixirWeb.Test.EditDriverVehiclePage do
  use Wallaby.DSL
  import Wallaby.Query

  def fill_fields(session, field_values, input_type) do
    Enum.each(field_values, fn {k, v} ->
      element = css("[data-test-id='#{k}-input']")

      fill_form_element(element, session, input_type, v)
    end)

    session
  end

  def fill_form_element(_element, session, "select", value) do
    set_value(session, css("option[value='#{value}']"), :selected)
  end

  def fill_form_element(element, session, _, value) do
    fill_in(session, element, with: value)
  end

  def assert_vehicle(session, map) do
    Enum.each(map, fn {k, v} -> assert_has(session, css("[data-test-id='#{k}']", text: v)) end)

    session
  end
end
