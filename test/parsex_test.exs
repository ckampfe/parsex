defmodule ParsexTest do
  use ExUnit.Case, async: true
  import Parsex

  test "string literal parsing" do
    assert({:ok, "", "foo"} = lit("foo").("foo"))
    assert({:error, _} = lit("foo").("bar"))
    assert(
      {:ok, " again", "we shall meet"} = lit("we shall meet").("we shall meet again")
    )
  end

  test "regex parsing" do
    assert(
      {:ok, "", "abc as easy as 123"} =
        pregex(~r/^\w{3} as easy as \d{3}/).("abc as easy as 123")
    )
  end

  test "or parsing" do
    assert(
      {:ok, "", "baz"} = por(
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
      {:ok, "", "foo bar"} = pand(
        [
          lit("foo"),
          lit("bar")
        ]
      ).("foo bar")
    )

    # completely parses given input
    assert(
      {:ok, "", "foo bar baz quux"} = pand(
        [
          lit("foo"),
          pand([lit("bar"), lit("baz"), lit("quux")])
        ]
      ).("foo bar baz quux")
    )

    # successfully parses, leaving some string leftover
    assert(
      {:ok, " quux", "foo bar baz"} = pand(
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

  test "and_then parsing" do
    assert(
      {:ok, "", "foo bar baz quuxquuxquux"} = pand(
         [
           lit("foo"),
           pand([lit("bar"), lit("baz")]),
           and_then(
             lit("quux"),
             fn value -> value <> value <> value end
           )
         ]
      ).("foo bar baz quux")
    )
  end

  test "replace parsing" do
    assert(
      {:ok, "", "han shot not even close to first"} = replace(
         lit("han shot first"),
         "han shot not even close to first"
      ).("han shot first")
    )

    assert(
      {:ok, "", "the year of our dark lord 2015"} = pand(
        [
          replace(lit("the year of our lord"), "the year of our dark lord"),
          replace(lit("1776"), "2015")
        ]
      ).("the year of our lord 1776")
    )

    assert(
      {:ok, "", "bar"} = replace(lit("foo"), :bar).("foo")
    )
  end
end
