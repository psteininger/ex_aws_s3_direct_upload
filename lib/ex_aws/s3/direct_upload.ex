defmodule ExAws.S3.DirectUpload do
  @moduledoc """

  Pre-signed S3 upload helper for client-side multipart POSTs, with support for using AWS Instance Roles,
  which produce temporary credentials. This approach reduces the number of ENV variables to pass, among other benefits.

  See:

  [Browser-Based Upload using HTTP POST (Using AWS Signature Version 4)](http://docs.aws.amazon.com/AmazonS3/latest/API/sigv4-post-example.html)

  [Task 3: Calculate the Signature for AWS Signature Version 4](http://docs.aws.amazon.com/general/latest/gr/sigv4-calculate-signature.html)

  This module does not require any further configuration other than the default already in place, when using `ex_aws` or `ex_aws_s3`.
  The default configuration is as follows:

  ```elixir
    config :ex_aws,
    access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}, :instance_role],
    secret_access_key: [{:system, "AWS_SECRET_ACCESS_KEY"}, :instance_role]
  ```
  The Authentication Resolver will look for credentials in ENV variables, and fall back to Instance Role.

  """

  @doc """

  The `S3DirectUpload` struct represents the data necessary to
  generate an S3 pre-signed upload object.

  The required fields are:

  - `file_name` the name of the file being uploaded
  - `mimetype` the mimetype of the file being uploaded
  - `path` the path where the file will be uploaded in the bucket
  - `bucket` the name of the bucket to which to upload the file

  Fields that can be over-ridden are:

  - `acl` defaults to `public-read`

  """
  defstruct file_name: nil, mimetype: nil, path: nil, acl: "public-read", bucket: nil

  @date_util Application.get_env(:ex_aws, :s3_direct_upload_date_util, ExAws.S3.DirectUpload.DateUtil)

  @doc """

  Returns a map with `url` and `credentials` keys.

  - `url` - the form action URL
  - `credentials` - name/value pairs for hidden input fields

  ## Examples

      iex> %ExAws.S3.DirectUpload{file_name: "image.jpg", mimetype: "image/jpeg", path: "path/to/file", bucket: "s3-bucket"}
      ...> |> ExAws.S3.DirectUpload.presigned
      ...> |> Map.get(:url)
      "https://s3-bucket.s3.us-east-1.amazonaws.com"

      iex> %ExAws.S3.DirectUpload{file_name: "image.jpg", mimetype: "image/jpeg", path: "path/to/file", bucket: "s3-bucket"}
      ...> |> ExAws.S3.DirectUpload.presigned
      ...> |> Map.get(:credentials) |> Map.get(:"x-amz-credential")
      "123abc/20170101/us-east-1/s3/aws4_request"

      iex> %ExAws.S3.DirectUpload{file_name: "image.jpg", mimetype: "image/jpeg", path: "path/to/file", bucket: "s3-bucket"}
      ...> |> ExAws.S3.DirectUpload.presigned
      ...> |> Map.get(:credentials) |> Map.get(:key)
      "path/to/file/image.jpg"

  """
  def presigned(%ExAws.S3.DirectUpload{} = upload, config \\ []) do
    %{
      url: url(upload, config),
      credentials: credentials(upload, config)
    }
  end

  @doc """

  Returns a json object with `url` and `credentials` properties.

  - `url` - the form action URL
  - `credentials` - name/value pairs for hidden input fields

  """
  def presigned_json(%ExAws.S3.DirectUpload{} = upload, config \\ []) do
    presigned(upload, config)
    |> Poison.encode!
  end

  defp credentials(%ExAws.S3.DirectUpload{} = upload, config) do
    credentials = %{
      policy: policy(upload, config),
      "x-amz-algorithm": "AWS4-HMAC-SHA256",
      "x-amz-credential": credential(config),
      "x-amz-date": @date_util.today_datetime(),
      "x-amz-signature": signature(upload, config),
      acl: upload.acl,
      key: file_path(upload)
    }
    credentials = case security_token(config) do
      nil -> credentials
      _ -> credentials |> Map.put(:"x-amz-security-token", security_token(config))
    end
    credentials
  end

  defp signature(%ExAws.S3.DirectUpload{} = upload, config) do
    signing_key(config)
    |> hmac(policy(upload, config))
    |> Base.encode16(case: :lower)
  end

  defp signing_key(config) do
    "AWS4#{secret_key(config)}"
    |> hmac(@date_util.today_date())
    |> hmac(region(config))
    |> hmac("s3")
    |> hmac("aws4_request")
  end

  defp policy(%ExAws.S3.DirectUpload{} = upload, config) do
    %{
      expiration: @date_util.expiration_datetime,
      conditions: conditions(upload, config)
    }
    |> Poison.encode!
    |> Base.encode64
  end

  defp conditions(%ExAws.S3.DirectUpload{} = upload, config) do
    conditions = [
      %{"bucket" => upload.bucket},
      %{"acl" => upload.acl},
      %{"x-amz-algorithm": "AWS4-HMAC-SHA256"},
      %{"x-amz-credential": credential(config)},
      %{"x-amz-date": @date_util.today_datetime()},
      ["starts-with", "$Content-Type", upload.mimetype],
      ["starts-with", "$key", upload.path]
    ]
    conditions = case security_token(config) do
      nil -> conditions
      _ -> [%{"x-amz-security-token" => security_token(config)} | conditions]
    end
    conditions
  end

  defp url(%ExAws.S3.DirectUpload{bucket: bucket}, config) do
    "https://#{bucket}.s3.#{region(config)}.amazonaws.com"
  end

  defp credential(config) do
    "#{access_key(config)}/#{@date_util.today_date()}/#{region(config)}/s3/aws4_request"
  end

  defp file_path(upload) do
    "#{upload.path}/#{upload.file_name}"
  end

  # :crypto.mac/4 is introduced in Erlang/OTP 22.1 and :crypto.hmac/3 is removed
  # in Erlang/OTP 24. The check is needed for backwards compatibility.
  # The Code.ensure_loaded/1 call is executed so function_expored?/3 can be used
  # to determine which function to use.

  Code.ensure_loaded?(:crypto) || IO.warn(":crypto module failed to load")
  case function_exported?(:crypto, :mac, 4) do
    true ->
      defp hmac(key, data) do
        :crypto.mac(:hmac, :sha256, key, data)
      end

    false ->
      defp hmac(key, data) do
        :crypto.hmac(:sha256, key, data)
      end
  end

  defp security_token(config) do
    ExAws.Config.new(:s3, config)
    |> Map.get(:security_token)
  end

  defp access_key(config) do
    ExAws.Config.new(:s3, config)
    |> Map.get(:access_key_id)
  end

  defp secret_key(config) do
    ExAws.Config.new(:s3, config)
    |> Map.get(:secret_access_key)
  end

  defp region(config) do
    ExAws.Config.new(:s3, config)
    |> Map.get(:region)
  end
end
