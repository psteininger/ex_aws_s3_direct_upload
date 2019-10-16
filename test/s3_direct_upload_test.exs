defmodule ExAws.S3.DirectUploadTest do
  use ExUnit.Case
#  use Mix.Config
  doctest ExAws.S3.DirectUpload

  import Map, only: [get: 2]

  test "presigned_json" do
    Mix.Config.read!("config/test.exs") |> Mix.Config.persist
    upload = %ExAws.S3.DirectUpload{ file_name: "file.jpg", mimetype: "image/jpeg", path: "path/in/bucket", bucket: "s3-bucket" }
    result = ExAws.S3.DirectUpload.presigned_json(upload) |> Poison.decode!
    assert result |> get("url") == "https://s3.us-east-1.amazonaws.com/s3-bucket"
    credentials = result |> get("credentials")
    assert credentials |> get("content-type") == "image/jpeg"
    assert credentials |> get("acl") == "public-read"
    assert credentials |> get("key") == "path/in/bucket/file.jpg"
    assert credentials |> get("policy") |> String.slice(0..9) == "eyJleHBpcm"
    assert credentials |> get("x-amz-algorithm") == "AWS4-HMAC-SHA256"
    assert credentials |> get("x-amz-credential") == "123abc/20170101/us-east-1/s3/aws4_request"
    assert credentials |> get("x-amz-date") == "20170101T000000Z"
    assert credentials |> get("x-amz-signature") == "1c1210287ea2cb1c915ee11b9515b2d811f4b21a90e78a45f12465974ebb95f1"
  end

  test "presigned_json_security_token" do
    Mix.Config.read!("config/test_with_token.exs") |> Mix.Config.persist
    upload = %ExAws.S3.DirectUpload{
      file_name: "file.jpg",
      mimetype: "image/jpeg",
      path: "path/in/bucket",
      bucket: "s3-bucket"
    }
    result = ExAws.S3.DirectUpload.presigned_json(upload) |> Poison.decode!
    assert result |> get("url") == "https://s3.us-east-1.amazonaws.com/s3-bucket"
    credentials = result |> get("credentials")
    assert credentials |> get("content-type") == "image/jpeg"
    assert credentials |> get("acl") == "public-read"
    assert credentials |> get("key") == "path/in/bucket/file.jpg"
    assert credentials |> get("policy") |> String.slice(0..9) == "eyJleHBpcm"
    assert credentials |> get("x-amz-algorithm") == "AWS4-HMAC-SHA256"
    assert credentials |> get("x-amz-credential") == "123abc/20170101/us-east-1/s3/aws4_request"
    assert credentials |> get("x-amz-date") == "20170101T000000Z"
    assert credentials |> get("x-amz-signature") == "d7937612e613b453f4deee7b8c6f832f1f0c5a194b56d3a781bce3b9acb965ce"
    assert credentials |> get("x-amz-security-token") == Application.get_env(:ex_aws, :security_token)
  end
end
