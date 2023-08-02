defmodule FraytElixirWeb.Test.AdminTablePage do
  use Wallaby.DSL
  import Wallaby.Query
  import ExUnit.Assertions

  def visit_page(session, page) do
    session |> visit("http://localhost:4002/admin/#{page}")
  end

  def sort_by(session, label) do
    session |> Browser.click(css(".sort", text: label))
  end

  def next_page(session, count \\ 1) do
    session |> Browser.click(css("[data-test-id='next-page']", count: count, at: 0))
  end

  def last_page(session, count \\ 1) do
    session |> Browser.click(css("[data-test-id='last-page']", count: count, at: 0))
  end

  def first_page(session, count \\ 1) do
    session |> Browser.click(css("[data-test-id='first-page']", count: count, at: 0))
  end

  def previous_page(session, count \\ 1) do
    session |> Browser.click(css("[data-test-id='prev-page']", count: count, at: 0))
  end

  def go_to_page(session, page, count \\ 1) do
    session
    |> set_value(css("option[value='#{page}']", count: count, at: 0), :selected)
  end

  def toggle_show_more(session, label) do
    session |> Browser.click(css("td", text: label))
  end

  def search(session, query, submit_type \\ :enter) do
    session
    |> fill_in(text_field("Search"), with: query)
    |> send_search(submit_type)
  end

  def filter_state(session, state) do
    session
    |> set_value(
      css("[data-test-id='filter-states'] option[value='#{state}']"),
      :selected
    )
  end

  defp send_search(session, :enter), do: session |> Browser.send_keys([:enter])
  defp send_search(session, :click), do: session |> Browser.click(css(".search__submit"))

  def test_sorting(session, sort_by, selector, total_results, first_result) do
    session
    |> sort_by(sort_by)
    |> has_text?(css("[data-test-id='#{selector}']", count: total_results, at: 0), first_result)

    session
  end

  def assert_has_text(session, selector, text) do
    session
    |> assert_text(selector, text)

    session
  end

  def refute_has_text(session, selector, text) do
    session
    |> has_text?(selector, text)
    |> refute

    session
  end

  def assert_textarea_text(session, text) do
    Query.text(text, count: 1)
    session
  end

  def refute_textarea_text(session, text) do
    Query.text(text, count: 0)
    session
  end

  def assert_checked(session, selector \\ "") do
    session
    |> assert_has(css("#{selector}[data-test-id='checked']"))
  end

  def refute_checked(session, selector \\ "") do
    session
    |> assert_has(css("#{selector}[data-test-id='unchecked']"))
  end

  def toggle_checkbox(session, selector \\ "") do
    session
    |> click(css(".slide label#{selector}"))
  end

  def on_page?(session, path) do
    assert current_path(session) =~ path

    session
  end

  def assert_selected(session, query) do
    assert selected?(session, query)

    session
  end
end
