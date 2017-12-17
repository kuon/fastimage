defmodule Fastimage.UnknownTypeError do
  @moduledoc """
  This exception is raised when the image type is unknown or unsupported by
  this library.
  """
  @supported_types ["gif", "png", "jpg", "bmp"]

  @type t :: Exception.t

  defexception message: """
  The image type is unknown.
  Only the types #{Enum.join(@supported_types, ", ")}are currently supported by this library.

  Please open an issue is in fact a supported type by this library.
  """

  @spec exception(nil) :: t
  def exception(_), do: %__MODULE__{}
end