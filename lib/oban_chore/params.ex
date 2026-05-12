defmodule ObanChore.Params do
  @moduledoc """
  Helpers for casting and validating chore parameters.
  """

  @doc """
  Casts string parameters to the types specified in the field definitions.
  """
  def cast(params, fields) do
    Enum.reduce(fields, %{}, fn {name, opts}, acc ->
      name_str = to_string(name)
      value = Map.get(params, name_str)
      type = Keyword.get(opts, :type, :string)

      case cast_value(value, type) do
        {:ok, casted} -> Map.put(acc, name, casted)
        :error -> acc
      end
    end)
  end

  defp cast_value(nil, _type), do: :error
  defp cast_value("", _type), do: :error

  defp cast_value(value, :integer) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> {:ok, int}
      :error -> :error
    end
  end

  defp cast_value(value, :boolean) when is_binary(value) do
    {:ok, value in ["true", "1", "on"]}
  end

  defp cast_value(value, :boolean) when is_boolean(value), do: {:ok, value}

  defp cast_value(value, :string), do: {:ok, to_string(value)}

  defp cast_value(value, _type), do: {:ok, value}

  @doc """
  Validates that all required fields are present in the casted params.
  """
  def validate(casted_params, fields) do
    errors =
      Enum.reduce(fields, %{}, fn {name, opts}, acc ->
        if Keyword.get(opts, :required) && !Map.has_key?(casted_params, name) do
          Map.put(acc, name, "is required")
        else
          acc
        end
      end)

    if map_size(errors) == 0, do: :ok, else: {:error, errors}
  end
end
