defmodule ParsexTest do
  use ExUnit.Case, async: true
  import Parsex

  test "lit/1 string literal parsing" do
    assert({:ok, "", "foo"} = lit("foo").("foo"))
    assert({:error, _} = lit("foo").("bar"))
    assert(
      {:ok, " again", "we shall meet"} = lit("we shall meet").("we shall meet again")
    )
  end

  test "pregex/1 regex parsing" do
    assert(
      {:ok, "", "abc as easy as 123"} =
        pregex(~r/^\w{3} as easy as \d{3}/).("abc as easy as 123")
    )
  end

  test "por/2 or parsing" do
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

  test "por/2 operator syntax" do
    foo_or_bar_or_baz = lit("foo") <|> lit("bar") <|> lit("baz")
    assert(
      {:ok, "", "baz"} = foo_or_bar_or_baz.("baz")
    )
  end

  test "pand/2 and parsing" do
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

  test "pand/2 operator syntax" do
    foo_and_bar = lit("foo") <~> lit("bar")
    assert(
      {:ok, "", "foo bar"} = foo_and_bar.("foo bar")
    )
  end

  test "and_keep_first/1 and_keep_first parsing" do
    assert(
      {:ok, "", "one"} = and_keep_first(
         [
           lit("one"),
           lit("day"),
           lit("son"),
           lit("this"),
           lit("will"),
           lit("all"),
           lit("be"),
           lit("yours")
         ]
      ).("one day son this will all be yours")
    )
  end

  test "and_keep_first/1 operator syntax" do
    one = lit("one") <~ lit("day son this will all be yours")
    assert(
      {:ok, "", "one"} =
        one.("one day son this will all be yours")
    )
  end

  test "and_keep_last/1 and_keep_last parsing" do
    assert(
      {:ok, "", "ahhh"} = and_keep_last(
         [
           lit("one"),
           lit("day"),
           lit("son"),
           lit("this"),
           lit("will"),
           lit("all"),
           lit("be"),
           lit("ahhh")
         ]
      ).("one day son this will all be ahhh")
    )

    assert(
      {:ok, "", "trailing whitespace "} = and_keep_last(
         [
           lit("should"),
           lit("leave"),
           lit("trailing whitespace ")
         ]
      ).("should leave trailing whitespace ")
    )
  end

  test "and_keep_last/1 operator syntax" do
    ahhh = lit("one day son this will all be") ~> lit("ahhh")
    assert(
      {:ok, "", "ahhh"} =
        ahhh.("one day son this will all be ahhh")
    )
  end

  test "and_then/2 and_then parsing" do
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

  test "and_then/2 operator syntax" do
    three_times = lit("quux") ~>> fn value -> value <> value <> value end
    assert(
      {:ok, "", "quuxquuxquux"} =
        three_times.("quux")
    )
  end

  test "replace/2 replace parsing" do
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
