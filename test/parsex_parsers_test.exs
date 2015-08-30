defmodule ParsexParsersTest do
  use ExUnit.Case, async: true
  use Parsex.Parsers

  test "string literal parsing" do
    assert({:ok, ""} = lit("foo").("foo"))
    assert({:error, _} = lit("foo").("bar"))
    assert({:ok, " again"} = lit("we shall meet").("we shall meet again"))
  end

  test "regex parsing" do
    assert({:ok, ""} = pregex(~r/^\w{3} as easy as \d{3}/).("abc as easy as 123"))
  end

  test "or parsing" do
    assert(
      {:ok, ""} = por(
        [
          lit("foo"),
          lit("bar"),
          lit("baz")
        ]
      ).("baz")
    )

    assert(
      {:error, _} = por(
        [
          lit("foo"),
          lit("bar"),
          lit("baz")
        ]
      ).("quux")
    )
  end

  test "and parsing" do
    assert(
      {:ok, ""} = pand(
        [
          lit("foo"),
          lit("bar")
        ]
      ).("foo bar")
    )

    # completely parses given input
    assert(
      {:ok, ""} = pand(
        [
          lit("foo"),
          pand([lit("bar"), lit("baz"), lit("quux")])
        ]
      ).("foo bar baz quux")
    )

    # successfully parses, leaving some string leftover
    assert(
      {:ok, " quux"} = pand(
        [
          lit("foo"),
          pand([lit("bar"), lit("baz")])
        ]
      ).("foo bar baz quux")
    )

    # doesn't have a third word
    assert(
      {:error, _} = pand(
        [
          lit("foo"),
          pand([lit("bar"), pregex(~r/\w+/)])
        ]
      ).("foo bar")
    )
  end
end
