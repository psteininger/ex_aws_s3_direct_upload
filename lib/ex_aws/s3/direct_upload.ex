defmodule ExAws.S3.DirectUpload do
  @moduledoc """

  Pre-signed S3 upload helper for client-side multipart POSTs

  While `ex_aws` itself allows generating signed requests, it is not usable for
  `POST` requests, which are required if you want to specify a custom policy
  (such as when you want to limit the file size of the upload). For details
  check out [Differences between PUT and POST S3 signed
  URLs](https://advancedweb.hu/differences-between-put-and-post-s3-signed-urls/)
  and the [AWS documentation about constructing a
  policy](https://docs.aws.amazon.com/AmazonS3/latest/API/sigv4-HTTPPOSTConstructPolicy.html).

  See also:

  [Browser-Based Upload using HTTP POST (Using AWS Signature Version
  4)](http://docs.aws.amazon.com/AmazonS3/latest/API/sigv4-post-example.html)

  [Task 3: Calculate the Signature for AWS Signature Version
  4](http://docs.aws.amazon.com/general/latest/gr/sigv4-calculate-signature.html)

  ### Example:
  ```elixir
    %{url: url, credentials: credentials} =
      %ExAws.S3.DirectUpload{
        filename: "${filename}",
        mimetype: "image/jpeg",
        path: "some/path/somewhere",
        bucket: "my-bucket",
        expiration: DateTime.utc_now |> DateTime.add(5 * 60, :second),
        additional_conditions: [["content-length-range", 0, 50 * 1024 * 1024]]
      }
      |> ExAws.S3.DirectUpload.presigned()
  ```
  """

  @doc """

  The `S3DirectUpload` struct represents the data necessary to
  generate an S3 pre-signed upload object.

  The required fields are:

  - `filename` the name of the file being uploaded
  - `mimetype` the mimetype of the file being uploaded
  - `path` the path where the file will be uploaded in the bucket
  - `bucket` the name of the bucket to which to upload the file

  Fields that can be over-ridden are:

  - `acl` defaults to `public-read`
  - `expiration` the expiration datetime of the signed request, defaults to 1h
    from now
  - `additional_condition` additional conditions to be added to the policy, for
    example pass in `[["content-length-range", 0, 50 * 1024 * 1024]]` to only
    allow files below 50MB. It's a list of maps or 3-element lists, see [AWS
    docs](https://docs.aws.amazon.com/AmazonS3/latest/API/sigv4-HTTPPOSTConstructPolicy.html)
    for details.

  """
  defstruct filename: nil,
            mimetype: nil,
            path: nil,
            acl: "public-read",
            bucket: nil,
            expiration: nil,
            additional_conditions: []

  import Jason.Helpers, only: [json_map: 1]

  @date_util Application.get_env(
               :ex_aws,
               :s3_direct_upload_date_util,
               ExAws.S3.DirectUpload.DateUtil
             )

  @default_expiration [60 * 60, :second]

  @doc """

  Returns a map with `url` and `credentials` keys.

  - `url` - the form action URL
  - `credentials` - name/value pairs for hidden input fields

  ## Examples

      iex> %ExAws.S3.DirectUpload{filename: "image.jpg", mimetype: "image/jpeg", path: "path/to/file", bucket: "s3-bucket"}
      ...> |> ExAws.S3.DirectUpload.presigned
      ...> |> Map.get(:url)
      "https://s3-bucket.s3.us-east-1.amazonaws.com"

      iex> %ExAws.S3.DirectUpload{filename: "image.jpg", mimetype: "image/jpeg", path: "path/to/file", bucket: "s3-bucket"}
      ...> |> ExAws.S3.DirectUpload.presigned
      ...> |> Map.get(:credentials) |> Map.get(:"x-amz-credential")
      "123abc/20170101/us-east-1/s3/aws4_request"

      iex> %ExAws.S3.DirectUpload{filename: "image.jpg", mimetype: "image/jpeg", path: "path/to/file", bucket: "s3-bucket"}
      ...> |> ExAws.S3.DirectUpload.presigned
      ...> |> Map.get(:credentials) |> Map.get(:key)
      "path/to/file/image.jpg"

  """
  def presigned(%ExAws.S3.DirectUpload{} = upload) do
    %{
      url: url(upload),
      credentials: credentials(upload)
    }
  end

  @doc """

  Returns a json object with `url` and `credentials` properties.

  - `url` - the form action URL
  - `credentials` - name/value pairs for hidden input fields

  """
  def presigned_json(%ExAws.S3.DirectUpload{} = upload) do
    presigned(upload)
    |> Jason.encode!()
  end

  defp credentials(%ExAws.S3.DirectUpload{} = upload) do
    credentials = %{
      policy: policy(upload),
      "x-amz-algorithm": "AWS4-HMAC-SHA256",
      "x-amz-credential": credential(),
      "x-amz-date": @date_util.format_datetime(DateTime.utc_now()),
      "x-amz-signature": signature(upload),
      acl: upload.acl,
      key: file_path(upload)
    }

    credentials =
      case security_token() do
        nil -> credentials
        _ -> credentials |> Map.put(:"x-amz-security-token", security_token())
      end

    credentials
  end

  defp signature(%ExAws.S3.DirectUpload{} = upload) do
    signing_key()
    |> hmac_sha256(policy(upload))
    |> Base.encode16(case: :lower)
  end

  defp signing_key do
    "AWS4#{secret_key()}"
    |> hmac_sha256(@date_util.format_date(Date.utc_today()))
    |> hmac_sha256(region())
    |> hmac_sha256("s3")
    |> hmac_sha256("aws4_request")
  end

  defp policy(%ExAws.S3.DirectUpload{} = upload) do
    # We do this to emulate the order of keys in JSON that Poison produces...
    expiration =
      Map.get(
        upload,
        :expiration,
        apply(DateTime, :add, [DateTime.utc_now()] ++ @default_expiration)
      )

    json_map(expiration: @date_util.format_expiration(expiration), conditions: conditions(upload))
    |> Jason.encode!()
    |> Base.encode64()
  end

  defp conditions(%ExAws.S3.DirectUpload{} = upload) do
    conditions = [
      %{"bucket" => upload.bucket},
      %{"acl" => upload.acl},
      %{"x-amz-algorithm": "AWS4-HMAC-SHA256"},
      %{"x-amz-credential": credential()},
      %{"x-amz-date": @date_util.format_datetime(DateTime.utc_now())},
      ["starts-with", "$Content-Type", upload.mimetype],
      ["starts-with", "$key", upload.path]
    ]

    conditions =
      case security_token() do
        nil -> conditions
        _ -> [%{"x-amz-security-token" => security_token()} | conditions]
      end

    conditions ++ upload.additional_conditions
  end

  defp url(%ExAws.S3.DirectUpload{bucket: bucket}) do
    "https://#{bucket}.s3.#{region()}.amazonaws.com"
  end

  defp credential() do
    "#{access_key()}/#{@date_util.format_date(Date.utc_today())}/#{region()}/s3/aws4_request"
  end

  defp file_path(upload) do
    "#{upload.path}/#{upload.filename}"
  end

  defp hmac_sha256(key, data) do
    :crypto.hmac(:sha256, key, data)
  end

  defp security_token do
    ExAws.Config.new(:s3)
    |> Map.get(:security_token)
  end

  defp access_key do
    ExAws.Config.new(:s3)
    |> Map.get(:access_key_id)
  end

  defp secret_key do
    ExAws.Config.new(:s3)
    |> Map.get(:secret_access_key)
  end

  defp region do
    ExAws.Config.new(:s3)
    |> Map.get(:region)
  end
end
