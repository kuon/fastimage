defmodule Fastimage.Adapters.Binary do
  alias Fastimage.{Dimensions, Parser}
  @chunk_size 500
  @type image_types :: :bmp | :gif | :jpg | :png | :unknown_type


  @doc """
  Gets the size of an image from a binary.

  ## Example

      iex> Fastimage.Adapters.Binary.size(filepath)
      {:ok, %Fastimage.Dimensions{width: 100, height: 50}}
  """
  @spec size(binary()) :: {:ok, Fastimage.Dimensions.t} | {:error, String.t}
  def size(bin) do
    with {:ok, data, binary_stream} = recv(bin, :binary),
         bytes <- :erlang.binary_part(data, {0, 2}),
         {:ok, type} <- bytes_type(bytes),
         dimensions = %Dimensions{width: _w, height: _h} <- Parser.size(type, data, binary_stream, :nil, :binary) do
      {:ok, dimensions}
    else
      {:error, msg} ->
        {:error, msg}
    end
  end

  @doc """
  Gets the size of an image from a binary.

  ## Example

      iex> Fastimage.Adapters.Binary.size!(filepath)
      %Fastimage.Dimensions{width: 100, height: 50}
  """
  @spec size!(binary()) :: binary() | no_return()
  def size!(bin) do
    case size(bin) do
      {:ok, %Dimensions{} = size} -> size
      {:error, msg} -> raise(inspect(msg))
    end
  end

  @doc """
  Gets the type of an image from a binary.

  ## Example

      iex> Fastimage.Adapters.Binary.type(filepath)
      "jpeg"
  """
  @spec type(binary()) :: {:ok, image_types()} | {:error, String.t}
  def type(bin) do
    case recv(bin, :binary) do
      {:ok, data, _bin_stream} ->
        bytes = :erlang.binary_part(data, {0, 2})
        bytes_type(bytes)
      {:error, msg} ->
        {:error, msg}
    end
  end

  @doc """
  Gets the type of an image from a binary.

  ## Example

      iex> Fastimage.Adapters.Url.type(bin)
      "jpeg"
  """
  @spec type!(binary()) :: binary() | no_return()
  def type!(bin) do
    case type(bin) do
      {:ok, bin} -> bin
      {:error, msg} -> raise(inspect(msg))
    end
  end

  # private or docless

  @spec recv(binary(), :binary) :: {:ok, binary(), Enumerable.t} | {:error, String.t}
  defp recv(bin, :binary) do
    binary_stream = binary_stream(bin)
    {:ok, _data, _binary_stream} = stream_chunks(binary_stream, 1, {0, <<>>, :nil}, 0, 0)
  end

  defp bytes_type(bytes) do
    cond do
      bytes == "BM" -> {:ok, "bmp"}
      bytes == "GI" -> {:ok, "gif"}
      bytes == <<255, 216>> -> {:ok, "jpeg"}
      bytes == (<<137>> <> "P") -> {:ok, "png"}
      :true -> {:error, :unknown_type}
    end
  end

  @doc false
  def stream_chunks(binary_stream, num_chunks_to_fetch, {acc_num_chunks, acc_data, :nil}, 0, 0) do
    cond do
      num_chunks_to_fetch == 0 ->
        {:ok, acc_data, binary_stream}
      num_chunks_to_fetch > 0 ->
        data = Enum.slice(binary_stream, acc_num_chunks, num_chunks_to_fetch)
        |> Enum.join()
        stream_chunks(binary_stream, num_chunks_to_fetch - 1,
          {acc_num_chunks + 1, <<acc_data::binary, data::binary>>, :nil}, 0, 0)
      true ->
        {:error, "unexpected binary streaming error"}
    end
  end

  # returns an enumerable Enumberable.t
  defp binary_stream(binary_data) do
    Stream.resource(
      fn -> binary_data end,
      fn(binary_data) ->
        case :erlang.byte_size(binary_data) > @chunk_size do
          true ->
            Og.log("***Logging context***", __ENV__, :debug)
            chunk = :binary.part(binary_data, 0, @chunk_size)
            |> Og.log_r(__ENV__, :debug)
            <<_chunk, next_binary_data::binary>> = binary_data
            {[chunk], next_binary_data}
          false ->
            final_chunk = binary_data
            {:halt, final_chunk}
        end
      end,
      fn(_last_chunk) -> :ok end
    )
  end
end