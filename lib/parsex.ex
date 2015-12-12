defmodule Parsex do
  @moduledoc """
  Parser combinator functions.
  """

  defmodule Parser do
    @type t :: (... -> {:ok, String.t, String.t} | {:error, String.t})
  end

  @doc """
  ######################
  ### STRING LITERAL ###
  ######################

  Creates a parser from a `String` literal that succeeds if the
  given string forms the prefix of the input.

  Input is stripped of leading spaces before match.

      iex> lit("foo").("foo")
      {:ok, "", "foo"}

      iex> lit("foo").("bar")
      {:error, "literal 'foo' did not match"}

      iex> lit("we shall meet").("we shall meet again")
      {:ok, " again", "we shall meet"}
  """
  @spec lit(String.t) :: Parser.t
  def lit(literal) do
    fn input ->
      if String.lstrip(input) |> String.starts_with?(literal) do
        literal_size = byte_size(literal)
        << _ :: binary-size(literal_size), rest :: binary >> = String.lstrip(input)

        {:ok, rest, pad(literal, input)}
      else
        {:error, "literal '#{literal}' did not match"}
      end
    end
  end

  @doc """
  #############
  ### REGEX ###
  #############

  Creates a parser from a Regex literal that succeeds if the
  given regular expression matches.

  Input is stripped of leading spaces before match

      iex> pregex(~r/^\\w{3} as easy as \\d{3}/).("abc as easy as 123")
      {:ok, "", "abc as easy as 123"}
  """
  @spec pregex(Regex.t) :: Parser.t
  def pregex(regex) do
    fn input ->
      if Regex.match?(regex, String.lstrip(input)) do
        result = Regex.run(regex, String.lstrip(input))

        # removes the result from the input
        remaining_input = Regex.replace(regex, String.lstrip(input), "")

        {
          :ok,
          remaining_input,
          result |> Enum.fetch!(0) |> pad(input)
        }
      else
        {:error, "Regex does not match on '#{String.lstrip(input)}'"}
      end
    end
  end

  @doc """
  ##########
  ### OR ###
  ##########

  Creates a logical `OR` parser from a collection of other parsers.
  This parser will succeed if at least one of its given parsers succeeds.

      iex> por([lit("foo"), lit("bar"), lit("baz")]).("baz")
      {:ok, "", "baz"}

      iex> por([lit("foo"), lit("bar"), lit("baz")]).("quux")
      {:error, "literal 'baz' did not match"}

  """
  @spec por([Parser.t]) :: Parser.t
  def por(parsers) do
    fn input ->
      do_por(parsers, input)
    end
  end

  # initial
  defp do_por(parsers, input) do
    [parser|remaining_parsers] = parsers
    do_por(parser, remaining_parsers, input)
  end

  # final
  defp do_por(parser, [], input) do
    parser.(input)
  end

  # build
  defp do_por(parser, parsers, input) do
    case parser.(input) do
      {:ok, remaining_input} -> {:ok, remaining_input}
      _ ->
        [next_parser|remaining_parsers] = parsers
        do_por(next_parser, remaining_parsers, input)
    end
  end

  @doc """
      iex> foo_or_bar_or_baz = lit("foo") <|> lit("bar") <|> lit("baz")
      iex> foo_or_bar_or_baz.("baz")
      {:ok, "", "baz"}
  """
  defmacro left <|> right do
    quote do
      por([unquote(left), unquote(right)])
    end
  end

  @doc """
  ###########
  ### AND ###
  ###########

  Creates a logical `AND` parser from a collection of other parsers.
  This parser will succeed if and only if all of its given parsers succeeds.

      iex> pand([lit("foo"), lit("bar")]).("foo bar")
      {:ok, "", "foo bar"}

      iex> pand([lit("foo"), pand([lit("bar"), lit("baz"), lit("quux")])]).("foo bar baz quux")
      {:ok, "", "foo bar baz quux"}

      iex> pand([lit("foo"), pand([lit("bar"), lit("baz")])]).("foo bar baz quux")
      {:ok, " quux", "foo bar baz"}

      iex> pand([lit("foo"), pand([lit("bar"), pregex(~r/\w+/)])]).("foo bar")
      {:error, "Regex does not match on ''"}
  """
  @spec pand([Parser.t]) :: Parser.t
  def pand(parsers) do
    fn input ->
      do_pand(parsers, input)
    end
  end

  # initial
  defp do_pand(parsers, input) do
    [parser|remaining_parsers] = parsers
    do_pand(parser, remaining_parsers, input, "")
  end

  # final
  defp do_pand(parser, [], input, previous_result) do
    parse_result = parser.(input)
    case parse_result do
      {:ok, remaining, new_result} ->
        {
          :ok,
          remaining,
          previous_result <> new_result
        }
      e -> e
    end
  end

  # build
  defp do_pand(parser, parsers, input, previous_result) do
    case parser.(input) do
      {:ok, remaining_input, new_result} ->
        [next_parser|remaining_parsers] = parsers

        do_pand(
          next_parser,
          remaining_parsers,
          remaining_input,
          previous_result <> new_result
        )
      e -> e
    end
  end

  @doc """
      iex> (lit("foo") <~> lit("bar")).("foo bar")
      {:ok, "", "foo bar"}
  """
  defmacro left <~> right do
    quote do
      pand([unquote(left), unquote(right)])
    end
  end


  @doc """
  ######################
  ### AND KEEP FIRST ###
  ######################

  Creates a logical `AND` parser from a collection of other parsers.
  In the case of a success, this parser will return only the result of
  the first given parser.

      iex> and_keep_first([
      ...> lit("one"),
      ...> lit("day"),
      ...> lit("son"),
      ...> lit("this"),
      ...> lit("will"),
      ...> lit("all"),
      ...> lit("be"),
      ...> lit("yours")]).("one day son this will all be yours")
      {:ok, "", "one"}

  """
  @spec and_keep_first([Parser.t]) :: Parser.t
  def and_keep_first(parsers) do
    parsers |> do_and_keep |> pand
  end

  @doc """
      iex> one = lit("one") <~ lit("day son this will all be yours")
      ...> one.("one day son this will all be yours")
      {:ok, "", "one"}
  """
  defmacro left <~ right do
    quote do
      and_keep_first([unquote(left), unquote(right)])
    end
  end

  @doc """
  #####################
  ### AND KEEP LAST ###
  #####################

  Creates a logical `AND` parser from a collection of other parsers.
  In the case of a success, this parser will return only the result of
  the last given parser.

      iex> and_keep_last([
      ...> lit("one"),
      ...> lit("day"),
      ...> lit("son"),
      ...> lit("this"),
      ...> lit("will"),
      ...> lit("all"),
      ...> lit("be"),
      ...> lit("ahhh")]).("one day son this will all be ahhh")
      {:ok, "", "ahhh"}


      iex> and_keep_last([
      ...> lit("should"),
      ...> lit("leave"),
      ...> lit("trailing whitespace ")]).("should leave trailing whitespace ")
      {:ok, "", "trailing whitespace "}

  """
  @spec and_keep_last([Parser.t]) :: Parser.t
  def and_keep_last(parsers) do
    parsers
    |> Enum.reverse
    |> do_and_keep
    |> Enum.reverse
    |> pand
  end

  @doc """
      iex> ahhh = lit("one day son this will all be") ~> lit("ahhh")
      ...> ahhh.("one day son this will all be ahhh")
      {:ok, "", "ahhh"}
  """
  defmacro left ~> right do
    quote do
      and_keep_last([unquote(left), unquote(right)])
    end
  end

  @doc """
  ################
  ### AND THEN ###
  ################

  Creates a parser from a given parser and a given function.
  Applies the function to the result of the given parser and
  returns the result.

      iex> pand([
      ...> lit("foo"),
      ...>   pand([lit("bar"), lit("baz")]),
      ...>   and_then(
      ...>     lit("quux"),
      ...>     fn value -> value <> value <> value end)
      ...>   ]).("foo bar baz quux")
      {:ok, "", "foo bar baz quuxquuxquux"}
  """
  @spec and_then(Parser.t, (... -> String.t)) :: Parser.t
  def and_then(parser, fun) do
    fn input ->
      case parser.(input) do
        {:ok, remaining_input, parse_result} ->
          transformed = fun.(String.lstrip(parse_result))
          {
            :ok,
            remaining_input,
            pad(transformed, input)
          }
        e -> e
      end
    end
  end

  @doc """
      iex> three_times = lit("quux") ~>> fn(value) -> value <> value <> value end
      ...> three_times.("quux")
      {:ok, "", "quuxquuxquux"}
  """
  defmacro left ~>> fun do
    quote do
      and_then(unquote(left), unquote(fun))
    end
  end

  @doc """
  ###############
  ### REPLACE ###
  ###############

  Creates a parser from a given parser and a given replacement value.
  Returns the replacement value in place of the result of the given parser.

      iex> replace(
      ...>   lit("han shot first"),
      ...>   "han shot not even close to first").("han shot first")
      {:ok, "", "han shot not even close to first"}

      iex> pand([
      ...> replace(lit("the year of our lord"), "the year of our dark lord"),
      ...> replace(lit("1776"), "2015")]).("the year of our lord 1776")
      {:ok, "", "the year of our dark lord 2015"}

      iex> replace(lit("foo"), :bar).("foo")
      {:ok, "", "bar"}
  """
  @spec replace(Parser.t, term) :: Parser.t
  def replace(parser, replacement) do
    and_then(parser, fn(_original_value) -> to_string(replacement) end)
  end

  @doc """
  #################
  ### UTILITIES ###
  #################
  """
  defp do_and_keep([first_parser|rest_of_parsers]) do
    fp = fn input ->
      {:ok, rem, res} = first_parser.(input)
      {:ok, rem, res |> String.lstrip}
    end

    [fp|(for parser <- rest_of_parsers, do: replace(parser, ""))]
  end

  defp pad(match, original_input) do
    if (match == "") do
      match
    else
      stripped_input = String.lstrip(original_input)
      pad_size =
        String.length(match) + String.length(original_input) - String.length(stripped_input)
      String.rjust(match, pad_size)
    end
  end
end
