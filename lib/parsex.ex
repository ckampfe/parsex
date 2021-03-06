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

  use Parsex.DefParser

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
  defparser str(prefix) do
    fn(input) ->
      case String.starts_with?(input, prefix) do
        true ->
          prefix_size = byte_size(prefix)
          << prefix::binary-size(prefix_size), remaining::bitstring>> = input
          %Parser.Success{result: prefix, remaining: remaining}
        false ->
          %Parser.Failure{parse_string: prefix, remaining: input}
      end
    end |> memo
  end

  @doc """
  Create the epsilon parser, that always succeeds, returning its given value.

      iex> an_eps = eps("an eps")
      iex> an_eps.("some input")
      %Parsex.Parser.Success{result: "an eps", remaining: "some input"}
  """
  @spec eps(String.t) :: Parser.t
  defparser eps(val \\ "") do
    fn(input) ->
      %Parser.Success{result: val, remaining: input}
    end |> memo
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
  defparser re(regex) do
    fn(input) ->
      case Regex.run(regex, input) do
        [matches] ->
          remaining = Regex.replace(regex, input, "")
          %Parser.Success{result: matches, remaining: remaining}
        nil -> %Parser.Failure{parse_string: regex.source, remaining: input}
      end
    end |> memo
  end

  @doc """
  Create a parser that succeeds if both of its subparsers succeed

      iex> p1 = str("foo")
      iex> p2 = str("bar")
      iex> foo_and_bar = cat(p1, p2)
      iex> foo_and_bar.("foobar")
      %Parsex.Parser.Success{result: "foobar", remaining: ""}

      iex> p1 = str("foo")
      iex> p2 = str("bar")
      iex> foo_and_bar = cat(p1, p2)
      iex> foo_and_bar.("foobaz")
      %Parsex.Parser.Failure{parse_string: "bar", remaining: "baz"}

      iex> p1 = str("foo")
      iex> p2 = str("bar")
      iex> foo_and_bar = cat(p1, p2)
      iex> foo_and_bar.("qoobar")
      %Parsex.Parser.Failure{parse_string: "foo", remaining: "qoobar"}
  """
  @spec cat(Parser.t, Parser.t) :: Parser.t
  defparser cat(parser1, parser2) do
    bind(parser1, fn(result1) ->
      bind(parser2, fn(result2) ->
        eps(result1 <> result2)
      end)
    end) |> memo
  end

  @doc """
  Macro sugar for `cat/2`

      iex> p1 = str("foo")
      iex> p2 = str("bar")
      iex> foo_and_bar = p1 <~> p2
      iex> foo_and_bar.("foobar")
      %Parsex.Parser.Success{result: "foobar", remaining: ""}
  """
  defmacro parser1 <~> parser2 do
    quote do
      cat(unquote(parser1), unquote(parser2))
    end
  end

  @doc """
  Creates a parser that succeeds if one of its subparsers succeeds

      iex> p1 = str("foo")
      iex> p2 = str("bar")
      iex> foo_and_bar = ord(p1, p2)
      iex> foo_and_bar.("foo")
      %Parsex.Parser.Success{result: "foo", remaining: ""}

      iex> p1 = str("foo")
      iex> p2 = str("bar")
      iex> foo_and_bar = ord(p1, p2)
      iex> foo_and_bar.("bar")
      %Parsex.Parser.Success{result: "bar", remaining: ""}

      iex> p1 = str("foo")
      iex> p2 = str("bar")
      iex> foo_and_bar = ord(p1, p2)
      iex> foo_and_bar.("bazquux")
      %Parsex.Parser.Failure{parse_string: "bar", remaining: "bazquux"}
  """
  @spec ord(Parser.t, Parser.t) :: Parser.t
  defparser ord(parser1, parser2) do
    fn(input) ->
      with %Parser.Success{} = s <- parser1.(input) do
        s
      else
        %Parsex.Parser.Failure{} -> parser2.(input)
      end
    end |> memo
  end

  @doc """
  Macro sugar for `ord/2`

      iex> p1 = str("foo")
      iex> p2 = str("bar")
      iex> foo_and_bar = p1 <|> p2
      iex> foo_and_bar.("foo")
      %Parsex.Parser.Success{result: "foo", remaining: ""}
  """
  defmacro parser1 <|> parser2 do
    quote do
      ord(unquote(parser1), unquote(parser2))
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
  defparser then(parser, function) do
    fn(input) ->
      case parser.(input) do
        %Parser.Success{result: result, remaining: remaining} ->
          %Parser.Success{result: function.(result), remaining: remaining}
        %Parser.Failure{} = e -> e
      end
    end |> memo
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

  @doc """
  A wrapper to provide a monadic bind, like Elixir's `with`.
  """
  @spec bind(Parser.t, (term -> Parser.t)) :: Parser.t
  defp bind(parser, function) do
    fn(input) ->
      with %Parser.Success{result: result, remaining: remaining} <- parser.(input) do
        function.(result).(remaining)
      end
    end
  end

  @doc """
  A simple to memoize the execution of a parser.
  Uses `Agent` to simulate mutable state.
  """
  @spec memo(fun) :: (term -> term)
  def memo(function) do
    {:ok, agent} = Agent.start_link(fn() -> %{} end)

    fn(args) ->
      Agent.get_and_update(
        agent,
        fn(state) ->
          case Map.fetch(state, args) do
            :error ->
              result = function.(args)
              {result, Map.put(state, args, result)}
            {:ok, value} -> {value, state}
          end
        end)
    end
  end
end
