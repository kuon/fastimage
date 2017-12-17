defmodule Fastimage.Parser do
  @moduledoc false
  alias Fastimage.Dimensions

  @doc false
  def size("bmp", data, _stream_ref, _source, _source_type) do
    parse_bmp(data)
  end
  def size("gif", data, _stream_ref, _source, _source_type) do
    parse_gif(data)
  end
  def size("png", data, _stream_ref, _source, _source_type) do
    parse_png(data)
  end
  def size("jpeg", data, stream_ref, source, :url) do
    chunk_size = :erlang.byte_size(data)
    parse_jpeg(stream_ref, {1, data, {source, Fastimage.Adapters.Url}}, data, 0, chunk_size, :initial)
  end
  def size("jpeg", data, stream_ref, source, :file) do
    chunk_size = :erlang.byte_size(data)
    parse_jpeg(stream_ref, {1, data, {source, Fastimage.Adapters.File}}, data, 0, chunk_size, :initial)
  end
  def size("jpeg", data, stream_ref, source, :binary) do
    chunk_size = :erlang.byte_size(data)
    parse_jpeg(stream_ref, {1, data, {source, Fastimage.Adapters.Binary}}, data, 0, chunk_size, :initial)
  end

  @doc false
  def parse_jpeg(stream_ref, {acc_num_chunks, acc_data, source}, next_data, num_chunks_to_fetch, chunk_size, state) do

    if :erlang.byte_size(next_data) < 4 do # get more data if less that 4 bytes remaining
      new_num_chunks_to_fetch = acc_num_chunks + 2
      parse_jpeg_with_more_data(stream_ref, {acc_num_chunks, acc_data, source},
        next_data, new_num_chunks_to_fetch, chunk_size, state)
    end

    case state do
      :initial ->
        skip = 2
        next_bytes = :erlang.binary_part(next_data, {skip, :erlang.byte_size(next_data) - skip})
        parse_jpeg(stream_ref, {acc_num_chunks, acc_data, source}, next_bytes,
          num_chunks_to_fetch, chunk_size, :start)

      :start ->
        next_bytes = next_bytes_until_match(<<255>>, next_data)
        parse_jpeg(stream_ref, {acc_num_chunks, acc_data, source}, next_bytes,
          num_chunks_to_fetch, chunk_size, :sof)

      :sof ->
        <<next_byte::8, next_bytes::binary>> = next_data
        cond do
          true == (next_byte == 225) ->
            # TODO - add option for exif information parsing here
            parse_jpeg(stream_ref, {acc_num_chunks, acc_data, source}, next_bytes,
              num_chunks_to_fetch, chunk_size, :skip)
          true == (next_byte in (224..239)) ->
            parse_jpeg(stream_ref, {acc_num_chunks, acc_data, source}, next_bytes,
              num_chunks_to_fetch, chunk_size, :skip)
          true == [(192..195), (197..199), (201..203), (205..207)] |>
            Enum.any?(fn(range) -> next_byte in range end) ->
            parse_jpeg(stream_ref, {acc_num_chunks, acc_data, source}, next_bytes,
              num_chunks_to_fetch, chunk_size, :read)
          true == (next_byte == 255) ->
            parse_jpeg(stream_ref, {acc_num_chunks, acc_data, source}, next_bytes,
              num_chunks_to_fetch, chunk_size, :sof)
          true ->
            parse_jpeg(stream_ref, {acc_num_chunks, acc_data, source}, next_bytes,
              num_chunks_to_fetch, chunk_size, :skip)
        end


      :skip ->
        <<u_int::unsigned-integer-size(16), next_bytes::binary>> = next_data
        skip = (u_int - 2)
        next_data_size = :erlang.byte_size(next_data)

        case skip >= (next_data_size - 10) do
          true ->
            num_chunks_to_fetch = (acc_num_chunks + Float.ceil(skip/chunk_size)) |> :erlang.round()
            parse_jpeg_with_more_data(stream_ref, {acc_num_chunks, acc_data, source}, next_data,
              num_chunks_to_fetch, chunk_size, :skip)
          false ->
            next_bytes = :erlang.binary_part(next_bytes, {skip, :erlang.byte_size(next_bytes) - skip})
            parse_jpeg(stream_ref, {acc_num_chunks, acc_data, source}, next_bytes,
              num_chunks_to_fetch, chunk_size, :start)
        end

      :read ->
        next_bytes = :erlang.binary_part(next_data, {3, :erlang.byte_size(next_data) - 3})
        <<height::unsigned-integer-size(16), next_bytes::binary>> = next_bytes
        <<width::unsigned-integer-size(16), _next_bytes::binary>> = next_bytes
        %Dimensions{width: width, height: height}
    end
  end

  @doc false
  defp parse_jpeg_with_more_data(stream_ref, {acc_num_chunks, acc_data, {source, adapter}},
         next_data, num_chunks_to_fetch, chunk_size, state) do
    case adapter.stream_chunks(stream_ref, num_chunks_to_fetch,
            {acc_num_chunks, acc_data, source}, 0, 0) do
      {:ok, new_acc_data, _stream_ref} ->
        num_bytes_old_data = :erlang.byte_size(acc_data) - :erlang.byte_size(next_data)
        new_next_data = :erlang.binary_part(new_acc_data, {num_bytes_old_data,
          :erlang.byte_size(new_acc_data) - num_bytes_old_data})
        _dimensions = parse_jpeg(stream_ref, {acc_num_chunks + num_chunks_to_fetch, new_acc_data, source},
          new_next_data, 0, chunk_size, state)
      {:error, msg} ->
        {:error, msg}
    end
  end

  @doc false
  defp parse_png(data) do
    next_bytes = :erlang.binary_part(data, {16, 8})
    <<width::unsigned-integer-size(32), next_bytes::binary>> = next_bytes
    <<height::unsigned-integer-size(32), _next_bytes::binary>> = next_bytes
    %Dimensions{width: width, height: height}
  end

  @doc false
  defp parse_gif(data) do
    next_bytes = :erlang.binary_part(data, {6, 4})
    <<width::little-unsigned-integer-size(16), rest::binary>> = next_bytes
    <<height::little-unsigned-integer-size(16), _rest::binary>> = rest
    %Dimensions{width: width, height: height}
  end

  @doc false
  defp parse_bmp(data) do
    new_bytes = :erlang.binary_part(data, {14, 14})
    <<char::8, _rest::binary>> = new_bytes
    %Dimensions{width: width, height: height} =
      case char do
        40 ->
          part = :erlang.binary_part(new_bytes, {4, :erlang.byte_size(new_bytes) - 5})
          <<width::little-unsigned-integer-size(32), rest::binary>> = part
          <<height::little-unsigned-integer-size(32), _rest::binary>> = rest
          %Dimensions{width: width, height: height}
        _ ->
          part = :erlang.binary_part(new_bytes, {4, 8})
          <<width::native-unsigned-integer-size(16), rest::binary>> = part
          <<height::native-unsigned-integer-size(16), _rest::binary>> = rest
          %Dimensions{width: width, height: height}
      end
    %Dimensions{width: width, height: height}
  end

  defp next_bytes_until_match(byte, bytes) do
    case matching_byte(byte, bytes) do
      true -> next_bytes(byte, bytes)
      false ->
        <<_discarded_byte, next_bytes::binary>> = bytes
        next_bytes_until_match(byte, next_bytes)
    end
  end

  defp matching_byte(<<byte?>>, bytes) do
    <<first_byte, _next_bytes::binary>> = bytes
    first_byte == byte?
  end

  defp next_bytes(_byte, bytes) do
    <<_byte, next_bytes::binary>> = bytes
    next_bytes
  end
end