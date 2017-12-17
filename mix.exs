defmodule Fastimage.Mixfile do
  use Mix.Project
  @name "Fastimage"
  @version "0.1.0"
  @source "https://github.com/stephenmoloney/fastimage"
  @maintainers ["Stephen Moloney"]
  @elixir_versions "~> 1.3 or ~> 1.4 or ~> 1.5"
  @hackney_versions "~> 1.6 or ~> 1.7 or ~> 1.8 or ~> 1.9 or ~> 1.10"

  def project do
    [
      app: :fastimage,
      name: @name,
      version: @version,
      source_url: @source,
      elixir: @elixir_versions,
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      description: description(),
      deps: deps(),
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:hackney, @hackney_versions},
      {:benchfella, "~> 0.3", only: [:dev]},
      {:credo, "~> 0.3", only: [:dev]},
      {:earmark, "~> 1.2", only: :dev},
      {:ex_doc, "~> 0.18", only: :dev},
      {:og, "~> 1.0", only: :dev}
    ]
  end


  defp description do
    """
    #{@name} finds the dimensions/size or file type of a remote
    or local image file given the file path or uri respectively.
    """
  end

  defp package do
    %{
      licenses: ["MIT"],
      maintainers: @maintainers,
      links: %{ "GitHub" => @source},
      files: ~w(priv bench/fastimage_bench.exs lib mix.exs README* LICENCE* CHANGELOG*)
     }
  end

  defp docs do
    [
      main: "api-reference"
    ]
  end
end
