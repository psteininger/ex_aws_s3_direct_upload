defmodule ExAws.S3.DirectUpload.TestDateUtil do
  @date ~D[2017-01-01]
  @datetime DateTime.from_naive!(~N[2017-01-01 00:00:00], "Etc/UTC")
  def datetime, do: @datetime

  alias ExAws.S3.DirectUpload.DateUtil

  def format_datetime(_), do: DateUtil.format_datetime(@datetime)
  def format_date(_), do: DateUtil.format_date(@date)

  def format_expiration(_),
    do: DateUtil.format_expiration(DateTime.add(@datetime, 60 * 60, :second))
end
