defmodule Fastimage do
  alias Fastimage.Adapters.{Binary, File, Url}
  alias Fastimage.{Dimensions, Utils}
#  @typep stream_ref :: reference | File.Stream | Enumerable.t

  @doc ~S"""
  Returns the type of file.

  Only "bmp", "gif", "jpeg" or "png" files are currently supported.
  """
  @spec type(binary() | String.t) ::{:ok,  String.t} | {:error, any()}
  def type(arg) when is_binary(arg) do
    cond do
      Utils.is_file?(arg) -> File.type(arg)
      Utils.is_url?(arg) -> Url.type(arg)
      is_binary(arg) -> Binary.type(arg)
      :true -> {:error, :unknown_type}
    end
  end

  @doc ~S"""
  Returns the type of file.

  Only "bmp", "gif", "jpeg" or "png" files are currently supported.
  """
  @spec type!(binary() | String.t) :: String.t | no_return()
  def type!(arg) when is_binary(arg) do
    cond do
      Utils.is_file?(arg) -> File.type!(arg)
      Utils.is_url?(arg) -> Url.type!(arg)
      is_binary(arg) -> Binary.type!(arg)
      :true -> raise("unkwown type")
    end
  end

  @doc """
  Returns the dimensions of the image.

  Supports "bmp", "gif", "jpeg" or "png" image files only.
  """
  @spec size(String.t | binary()) :: {:ok, Dimensions.t} | {:error, any()}
  def size(arg) when is_binary(arg) do
    cond do
      Utils.is_file?(arg) -> File.size(arg)
      Utils.is_url?(arg) -> Url.size(arg)
      is_binary(arg) -> Binary.size(arg)
      :true -> {:error, :unknown_size}
    end
  end

  @doc """
  Returns the dimensions of the image.

  Supports "bmp", "gif", "jpeg" or "png" image files only.
  """
  @spec size!(String.t | binary()) :: Dimensions.t | no_return()
  def size!(arg) when is_binary(arg) do
    cond do
      Utils.is_file?(arg) -> File.size!(arg)
      Utils.is_url?(arg) -> Url.size!(arg)
      is_binary(arg) -> Binary.size!(arg)
      :true -> raise("unkwown size")
    end
  end

end
