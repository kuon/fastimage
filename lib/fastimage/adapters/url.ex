defmodule Fastimage.Adapters.Url do
  @moduledoc """
  Gets the size or type of an image url.
  """
  alias Fastimage.{Dimensions, Parser}
  @stream_timeout 5000
  @max_error_retries 5

  @doc """
  Gets the size of an image from a  Url.

  ## Example

      iex> Fastimage.Adapters.Url.size(url)
      %Fastimage.Dimensions{width: 100, height: 50}
  """
  @spec size(String.t) :: {:ok, Fastimage.Dimensions.t} | {:error, String.t}
  def size(url) do
    with {:ok, data, stream_ref} = recv(url, :url, 0, 0) |> Og.log_r(__ENV__, :debug),
      bytes <- :erlang.binary_part(data, {0, 2}) |> Og.log_r(__ENV__, :debug),
      {:ok, type} <- type(bytes, stream_ref, [close_stream: false]) |> Og.log_r(__ENV__, :debug),
      dimensions = %Dimensions{width: _w, height: _h} <- Parser.size(type, data, stream_ref, url, :url) do
      close_stream(stream_ref)
      {:ok, dimensions}
    else
      {:error, msg} ->
        {:error, msg}
    end
  end

  @doc """
  Gets the size of an image from a  Url.

  ## Example

      iex> Fastimage.Adapters.Url.size(url)
      %Dimensions{width: 100, height: 50}
  """
  @spec size!(String.t) :: Fastimage.Dimensions.t | no_return()
  def size!(url) do
    case size(url) do
      {:ok, %Dimensions{} = dimensions} -> dimensions
      {:error, error} -> raise(inspect(error))
    end
  end

  @doc """
  Gets the type of an image from a Url.

  ## Example

      iex> Fastimage.Adapters.Url.type(url)
      "jpeg"
  """
  @spec type(String.t) :: {:ok, String.t} | {:error, String.t}
  def type(url) do
    case recv(url, :url, 0, 0) |> Og.log_r(__ENV__, :debug) do
      {:ok, data, stream_ref} ->
        bytes = :erlang.binary_part(data, {0, 2})
        type(bytes, stream_ref, [close_stream: :true])
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

  @doc false
  @spec recv(String.t, :url, integer(), integer) ::
          {:ok, binary(), reference()} | {:error, String.t}
  def recv(url, :url, num_redirects, _error_retries) when num_redirects > 3 do
    msg = """
    error #{num_redirects} redirects have already been attempted,
    check that image url #{url} is valid and reachable.
    """
    {:error, msg}
  end
  def recv(url, :url, num_redirects, error_retries) do
    {:ok, stream_ref} = :hackney.get(url, [], <<>>, [{:async, :once}, {:follow_redirect, true}])
    stream_chunks(stream_ref, 1, {0, <<>>, url}, num_redirects, error_retries) # returns {:ok, data, ref}
  end

  defp type(bytes, stream_ref, opts) do
    case Keyword.get(opts, :close_stream, :false) do
      :true -> close_stream(stream_ref)
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
  def stream_chunks(stream_ref, num_chunks_to_fetch, {acc_num_chunks, acc_data, url}, num_redirects, error_retries)
       when is_reference(stream_ref) do
    cond do
      num_chunks_to_fetch == 0 ->
        {:ok, acc_data, stream_ref}
      num_chunks_to_fetch > 0 ->
        _next_chunk = :hackney.stream_next(stream_ref)
        process_hackney_stream(stream_ref, num_chunks_to_fetch, {acc_num_chunks, acc_data, url}, num_redirects, error_retries)
      true ->
        {:error, "unexpected http streaming error"}
    end
  end

  defp process_hackney_stream(stream_ref, num_chunks_to_fetch, {acc_num_chunks, acc_data, url}, num_redirects, error_retries) do
    receive do
      {:hackney_response, stream_ref, {:status, status_code, reason}} ->
        case status_code <= 400 do
          false ->
            msg = "error, could not open image file with error #{status_code} due to reason, #{reason}"
            {:error, msg}
          true ->
            stream_chunks(stream_ref, num_chunks_to_fetch,
              {acc_num_chunks, acc_data, url}, num_redirects, error_retries)
        end
      {:hackney_response, stream_ref, {:headers, _headers}} ->
        stream_chunks(stream_ref, num_chunks_to_fetch,
          {acc_num_chunks, acc_data, url}, num_redirects, error_retries)
      {:hackney_response, stream_ref, {:redirect, to_url, _headers}} ->
        close_stream(stream_ref)
        recv(to_url, :url, num_redirects + 1, error_retries)
      {:hackney_response, stream_ref, :done} ->
        {:ok, acc_data, stream_ref}
      {:hackney_response, stream_ref, data} ->
        stream_chunks(stream_ref, num_chunks_to_fetch - 1,
          {acc_num_chunks + 1, <<acc_data::binary, data::binary>>, url}, num_redirects, error_retries)
      _ ->
        msg = "error, unexpected streaming error while streaming chunks"
        {:error, msg}
    after @stream_timeout ->
      msg = "error, uri stream timeout #{@stream_timeout} exceeded too many times"
      case error_retries < @max_error_retries do
        true ->
          close_stream(stream_ref)
          recv(url, :url, num_redirects, error_retries + 1)
        false ->
          {:error, msg}
      end
    end
  end

  defp close_stream(stream_ref) when is_reference(stream_ref) do
    :hackney.cancel_request(stream_ref)
    :hackney.close(stream_ref)
  end
end