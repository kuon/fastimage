defmodule Fastimage.Adapters.File do
  alias Fastimage.{Dimensions, Parser}
  @file_chunk_size 500

  @doc """
  Gets the size of an image from a  File.

  ## Example

      iex> Fastimage.Adapters.File.size(filepath)
      %Fastimage.Dimensions{width: 100, height: 50}
  """
  @spec size(String.t) :: {:ok, Fastimage.Dimensions.t} | {:error, String.t}
  def size(file) do
    with {:ok, data, file_stream} = recv(file, :file),
         bytes <- :erlang.binary_part(data, {0, 2}),
         {:ok, type} <- type(bytes, file_stream, [close_stream: false]),
         dimensions = %Dimensions{width: _w, height: _h} <- Parser.size(type, data, file_stream, file, :file) do
      close_stream(file_stream)
      {:ok, dimensions}
    else
      {:error, msg} ->
        {:error, msg}
    end
  end

  @doc """
  Gets the size of an image from a  File.

  ## Example

      iex> Fastimage.Adapters.File.size!(filepath)
      %Fastimage.Dimensions{width: 100, height: 50}
  """
  @spec size(String.t) :: Fastimage.Dimensions.t | no_return()
  def size!(filepath) do
    case size(filepath) do
      {:ok, %Dimensions{} = size} -> size
      {:error, msg} -> raise(inspect(msg))
    end
  end

  @doc """
  Gets the type of an image from a file.

  ## Example

      iex> Fastimage.Adapters.File.type(filepath)
      "jpeg"
  """
  @spec type(String.t) :: {:ok, String.t} | {:error, String.t}
  def type(file) do
    case recv(file, :file) do
      {:ok, data, file_stream} ->
        bytes = :erlang.binary_part(data, {0, 2})
        type(bytes, file_stream, [close_stream: :true])
      {:error, msg} ->
        {:error, msg}
    end
  end

  @doc """
  Gets the type of an image from a Url.

  ## Example

      iex> Fastimage.Adapters.Url.type(url)
      "jpeg"
  """
  @spec type!(String.t) :: String.t | no_return()
  def type!(url) do
    case type(url) do
      {:ok, type} -> type
      {:error, msg} -> raise(inspect(msg))
    end
  end

  # private or docless

  @spec recv(String.t, :file) ::
          {:ok, binary(), File.Stream.t} | {:error, String.t}
  defp recv(file_path, :file) do
    file_stream = File.stream!(file_path, [:read, :compressed, :binary], @file_chunk_size)
    {:ok, _data, _file_stream} = stream_chunks(file_stream, 1, {0, <<>>, file_path}, 0, 0)
  end

  defp type(bytes, file_stream, opts) do
    case Keyword.get(opts, :close_stream, :false) do
      :true -> close_stream(file_stream)
      :false -> :ok
    end
    cond do
      bytes == "BM" -> {:ok, "bmp"}
      bytes == "GI" -> {:ok, "gif"}
      bytes == <<255, 216>> -> {:ok, "jpeg"}
      bytes == (<<137>> <> "P") -> {:ok, "png"}
      :true -> {:error, "unknown or unsupport type"}
    end
  end

  @doc false
  def stream_chunks(%File.Stream{} = file_stream, num_chunks_to_fetch, {acc_num_chunks, acc_data, file_path}, 0, 0) do
    cond do
      num_chunks_to_fetch == 0 ->
        {:ok, acc_data, file_stream}
      num_chunks_to_fetch > 0 ->
        data = Enum.slice(file_stream, acc_num_chunks, num_chunks_to_fetch)
        |> Enum.join()
        stream_chunks(file_stream, 0,
        {acc_num_chunks + num_chunks_to_fetch, <<acc_data::binary, data::binary>>, file_path}, 0, 0)
      true ->
        {:error, "unexpected file streaming error"}
    end
  end

  defp close_stream(%File.Stream{} = file_stream) do
    File.close(file_stream.path)
  end
end