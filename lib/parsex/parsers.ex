defmodule Parsex.Parsers do

  @type parser :: (... -> {:ok, String.t} | {:error, String.t})

  defmacro __using__(_opts) do
    quote do
      import Parsex.Parsers
    end
  end

  ######################
  ### STRING LITERAL ###
  ######################

  @spec lit(String.t) :: parser
  def lit(lit) do
    fn input ->
      if String.lstrip(input) |> String.starts_with?(lit) do
        lit_size = byte_size(lit)
        << _ :: binary-size(lit_size), rest :: binary >> = String.lstrip(input)
        {:ok, rest}
      else
        {:error, "lit '#{lit}' did not match"}
      end
    end
  end

  #############
  ### REGEX ###
  #############

  @spec pregex(Regex.t) :: parser
  def pregex(regex) do
    fn input ->
      if Regex.match?(regex, String.lstrip(input)) do
        # replace with nothing, so return remaining
        remaining_input = Regex.replace(regex, String.lstrip(input), "")
        {:ok, remaining_input}
      else
        {:error, "Regex does not match"}
      end
    end
  end

  ##########
  ### OR ###
  ##########

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

  ###########
  ### AND ###
  ###########

  @spec pand([parser]) :: parser
  def pand(parsers) do
    fn input ->
      do_pand(parsers, input)
    end
  end

  # initial
  defp do_pand(parsers, input) do
    [parser|remaining_parsers] = parsers
    do_pand(parser, remaining_parsers, input)
  end

  # final
  defp do_pand(parser, [], input) do
    parser.(input)
  end

  # build
  defp do_pand(parser, parsers, input) do
    case parser.(input) do
      {:ok, remaining_input} ->
        [next_parser|remaining_parsers] = parsers
        do_pand(next_parser, remaining_parsers, remaining_input)
      {:error, e} -> {:error, e}
    end
  end
end
