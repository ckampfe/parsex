defmodule Parsex.DefParser do
  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__)
    end
  end

  defmacro defparser(call, do: block) do
    quoted_memo_call = quote do
      Parsex.memo(
        fn(_args) -> unquote(block) end
      )
    end

    quote do
      def unquote(call) do
        unquote(quoted_memo_call).(nil)
      end
    end
  end
end
