defmodule Watch.Mixfile do
  use Mix.Project

  def project do
    [app: :watch,
     version: "0.0.1",
     elixir:  ">= 1.0",
     deps:   []]
  end

  def application do
    [applications: [:logger]]
  end

end
