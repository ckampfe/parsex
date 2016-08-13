defmodule Parsex.Mixfile do
  use Mix.Project

  def project do
    [app: :parsex,
     version: "0.0.1",
     name: "Parsex",
     source_url: "https://github.com/ckampfe/parsex",
     homepage_url: "http://ckampfe.github.io/parsex",
     elixir: ">= 1.0.0",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    [{:ex_doc, "~> 0.13", only: :dev}]
  end
end
