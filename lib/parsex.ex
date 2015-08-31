defmodule Parsex do
  @moduledoc """
  Parser combinator functions.
  """

  @type parser :: (... -> {:ok, String.t} | {:error, String.t})

  @doc """
  ######################
  ### STRING LITERAL ###
  ######################

  Creates a parser from a `String` literal that succeeds if the
  given string forms the prefix of the input.

  Input is stripped of leading spaces before match.
  """
  @spec lit(String.t) :: parser
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
  """
  @spec pregex(Regex.t) :: parser
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
        {:error, "Regex does not match"}
      end
    end
  end

  @doc """
  ##########
  ### OR ###
  ##########

  Creates a logical `OR` parser from a collection of other parsers.
  This parser will succeed if at least one of its given parsers succeeds.
  """
  @spec por([parser]) :: parser
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
      {:error, _e} ->
        [next_parser|remaining_parsers] = parsers
        do_por(next_parser, remaining_parsers, input)
    end
  end

  @doc """
  ###########
  ### AND ###
  ###########

  Creates a logical `AND` parser from a collection of other parsers.
  This parser will succeed if and only if all of its given parsers succeeds.
  """
  @spec pand([parser]) :: parser
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
      _ -> parse_result
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
      {:error, e} -> {:error, e}
    end
  end

  @doc """
  #################
  ### UTILITIES ###
  #################
  """
  defp pad(match, original_input) do
    stripped_input = String.lstrip(original_input)
    pad_size =
      String.length(match) + String.length(original_input) - String.length(stripped_input)
    String.rjust(match, pad_size)
  end
end
