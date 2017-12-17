defmodule Fastimage.Utils do
  @moduledoc false

  @doc false
  def is_url?(url) when is_binary(url) do
    try do
      is_url?(URI.parse(url))
    rescue
      _error -> false
    end
  end
  def is_url?(%URI{scheme: :nil}) do
    false
  end
  def is_url?(%URI{host: :nil}) do
    false
  end
  def is_url?(%URI{path: :nil}) do
    false
  end
  def is_url?(%URI{}) do
    true
  end


  @doc false
  def is_file?(file) do
    File.exists?(file)
  end
end