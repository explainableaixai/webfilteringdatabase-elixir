defmodule WebFilteringDatabase.MixProject do
  use Mix.Project

  def project,
    do: [
      app: :webfilteringdatabase,
      version: "1.0.0",
      elixir: "~> 1.14",
      description: "Elixir client for Web Filtering Database.",
      package: package(),
      deps: deps(),
      docs: [main: "readme", extras: ["README.md"]],
      source_url: "https://github.com/explainableaixai/webfilteringdatabase-elixir",
      homepage_url: "https://www.webfilteringdatabase.com"
    ]

  def application, do: [extra_applications: [:logger]]
  defp deps, do: [{:req, "~> 0.5"}, {:ex_doc, "~> 0.34", only: :dev, runtime: false}]

  defp package,
    do: [
      licenses: ["MIT"],
      files: ~w(lib mix.exs README.md CHANGELOG.md LICENSE),
      links: %{
        "Homepage" => "https://www.webfilteringdatabase.com",
        "GitHub" => "https://github.com/explainableaixai/webfilteringdatabase-elixir"
      }
    ]
end
