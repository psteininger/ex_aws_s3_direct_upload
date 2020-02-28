defmodule ExAws.S3.DirectUpload.DateUtil do
  @moduledoc false
  def format_datetime(date) do
    %{date | hour: 0, minute: 0, second: 0, microsecond: {0, 0}}
    |> DateTime.to_iso8601(:basic)
  end

  def format_date(date), do: Date.to_iso8601(date, :basic)

  def format_expiration(date), do: DateTime.to_iso8601(date)
end
