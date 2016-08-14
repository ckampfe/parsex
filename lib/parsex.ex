defmodule Parsex do
  @moduledoc """
  Parser combinator functions.
  """

  defmodule Parser do
    @typep input :: String.t
    @type t :: (input -> Parser.Success.t | Parser.Failure.t)

    defmodule Success do
      @type t :: %__MODULE__{result: String.t, remaining: String.t}
      defstruct [
        result: "",
        remaining: ""
      ]
    end

    defmodule Failure do
      @type t :: %__MODULE__{parse_string: String.t, remaining: String.t}
      defstruct [
        parse_string: "",
        remaining: ""
      ]
    end
  end

  @doc """
  Create a parser from a `String.t`.

      iex> foo = str("foo")
      iex> foo.("foo bar")
      %Parsex.Parser.Success{result: "foo", remaining: " bar"}

      iex> foo = str("foo")
      iex> foo.("baz quux")
      %Parsex.Parser.Failure{parse_string: "foo", remaining: "baz quux"}
  """
  @spec str(String.t) :: Parser.t
  def str(prefix) do
    fn(input) ->
      case String.starts_with?(input, prefix) do
        true ->
          prefix_size = byte_size(prefix)
          << prefix::binary-size(prefix_size), remaining::bitstring>> = input
          %Parser.Success{result: prefix, remaining: remaining}
        false ->
          %Parser.Failure{parse_string: prefix, remaining: input}
      end
    end
  end

  @doc """
  Create the epsilon parser, that always succeeds, returning its given value.

      iex> an_eps = eps("an eps")
      iex> an_eps.("some input")
      %Parsex.Parser.Success{result: "an eps", remaining: "some input"}
  """
  @spec eps(String.t) :: Parser.t
  def eps(val \\ "") do
    fn(input) ->
      %Parser.Success{result: val, remaining: input}
    end
  end

  @doc """
  Create a parser from a regular expression

      iex> foo = re(~r/foo/)
      iex> foo.("foo bar")
      %Parsex.Parser.Success{result: "foo", remaining: " bar"}

      iex> foo = re(~r/foo/)
      iex> foo.("bar baz")
      %Parsex.Parser.Failure{parse_string: "foo", remaining: "bar baz"}
  """
  @spec re(String.t) :: Parser.t
  def re(regex) do
    fn(input) ->
      case Regex.run(regex, input) do
        [matches] ->
          remaining = Regex.replace(regex, input, "")
          %Parser.Success{result: matches, remaining: remaining}
        nil -> %Parser.Failure{parse_string: regex.source, remaining: input}
      end
    end
  end

  @doc """
  Create a parser that succeeds if both of its subparsers succeed

      iex> p1 = str("foo")
      iex> p2 = str("bar")
      iex> foo_and_bar = andd(p1, p2)
      iex> foo_and_bar.("foobar")
      %Parsex.Parser.Success{result: "foobar", remaining: ""}

      iex> p1 = str("foo")
      iex> p2 = str("bar")
      iex> foo_and_bar = andd(p1, p2)
      iex> foo_and_bar.("foobaz")
      %Parsex.Parser.Failure{parse_string: "bar", remaining: "baz"}

      iex> p1 = str("foo")
      iex> p2 = str("bar")
      iex> foo_and_bar = andd(p1, p2)
      iex> foo_and_bar.("qoobar")
      %Parsex.Parser.Failure{parse_string: "foo", remaining: "qoobar"}
  """
  @spec andd(Parser.t, Parser.t) :: Parser.t
  def andd(parser1, parser2) do
    fn(input) ->
      with %Parser.Success{
            result: result1,
            remaining: remaining1} <- parser1.(input),
           %Parser.Success{
             result: result2,
             remaining: remaining2} <- parser2.(remaining1) do
        %Parser.Success{result: result1 <> result2, remaining: remaining2}
      else
        %Parsex.Parser.Failure{} = e -> e
      end
    end
  end

  @doc """
  Macro sugar for `andd/2`

      iex> p1 = str("foo")
      iex> p2 = str("bar")
      iex> foo_and_bar = p1 <~> p2
      iex> foo_and_bar.("foobar")
      %Parsex.Parser.Success{result: "foobar", remaining: ""}
  """
  defmacro parser1 <~> parser2 do
    quote do
      andd(unquote(parser1), unquote(parser2))
    end
  end

  @doc """
  Creates a parser that succeeds if one of its subparsers succeeds
      iex> p1 = str("foo")
      iex> p2 = str("bar")
      iex> foo_and_bar = orr(p1, p2)
      iex> foo_and_bar.("foo")
      %Parsex.Parser.Success{result: "foo", remaining: ""}

      iex> p1 = str("foo")
      iex> p2 = str("bar")
      iex> foo_and_bar = orr(p1, p2)
      iex> foo_and_bar.("bar")
      %Parsex.Parser.Success{result: "bar", remaining: ""}

      iex> p1 = str("foo")
      iex> p2 = str("bar")
      iex> foo_and_bar = orr(p1, p2)
      iex> foo_and_bar.("bazquux")
      %Parsex.Parser.Failure{parse_string: "bar", remaining: "bazquux"}
  """
  @spec orr(Parser.t, Parser.t) :: Parser.t
  def orr(parser1, parser2) do
    fn(input) ->
      with %Parser.Success{} = s <- parser1.(input) do
        s
      else
        %Parsex.Parser.Failure{} -> parser2.(input)
      end
    end
  end

  @doc """
  Macro sugar for `orr/2`

      iex> p1 = str("foo")
      iex> p2 = str("bar")
      iex> foo_and_bar = p1 <|> p2
      iex> foo_and_bar.("foo")
      %Parsex.Parser.Success{result: "foo", remaining: ""}
  """
  defmacro parser1 <|> parser2 do
    quote do
      orr(unquote(parser1), unquote(parser2))
    end
  end


  @doc """
  Create a parser that transforms a successful parse

      iex> foo = str("foo") |> then(fn(result) -> result <> "bar" end)
      iex> foo.("foo")
      %Parsex.Parser.Success{result: "foobar", remaining: ""}

      iex> foo = str("foo") |> then(fn(result) -> result <> "bar" end)
      iex> foo.("quux")
      %Parsex.Parser.Failure{parse_string: "foo", remaining: "quux"}
  """
  @spec then(Parser.t, (String.t -> term)) :: Parser.t
  def then(parser, function) do
    fn(input) ->
      case parser.(input) do
        %Parser.Success{result: result, remaining: remaining} ->
          %Parser.Success{result: function.(result), remaining: remaining}
        %Parser.Failure{} = e -> e
      end
    end
  end

  @doc """
  Macro sugar for `then/2`

      iex> foo = str("foo") ~>> fn(result) -> result <> "bar" end
      iex> foo.("foo")
      %Parsex.Parser.Success{result: "foobar", remaining: ""}
  """
  defmacro parser1 ~>> function do
    quote do
      then(unquote(parser1), unquote(function))
    end
  end
end
