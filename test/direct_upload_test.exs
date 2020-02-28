defmodule ExAws.S3.DirectUploadTest do
  use ExUnit.Case
  doctest ExAws.S3.DirectUpload
  import Map, only: [get: 2]

  setup context do
    security_token = Map.get(context, :security_token)
    Application.put_env(:ex_aws, :security_token, security_token)

    {:ok,
     %{
       upload: %ExAws.S3.DirectUpload{
         filename: "file.jpg",
         mimetype: "image/jpeg",
         path: "path/in/bucket",
         bucket: "s3-bucket"
       }
     }}
  end

  describe "presigned_json" do
    import ExAws.S3.DirectUpload

    test "presigned_json", %{upload: upload} do
      result = presigned_json(upload) |> Jason.decode!()
      assert result |> get("url") == "https://s3-bucket.s3.us-east-1.amazonaws.com"
      credentials = result |> get("credentials")
      assert credentials |> get("acl") == "public-read"
      assert credentials |> get("key") == "path/in/bucket/file.jpg"
      assert credentials |> get("policy") |> String.slice(0..9) == "eyJleHBpcm"
      assert credentials |> get("x-amz-algorithm") == "AWS4-HMAC-SHA256"
      assert credentials |> get("x-amz-credential") == "123abc/20170101/us-east-1/s3/aws4_request"
      assert credentials |> get("x-amz-date") == "20170101T000000Z"

      assert credentials |> get("x-amz-signature") ==
               "1c1210287ea2cb1c915ee11b9515b2d811f4b21a90e78a45f12465974ebb95f1"
    end

    test "presigned_json with additional conditions", %{upload: upload} do
      upload = %{
        upload
        | additional_conditions: [
            ["content-length-range", 0, 1024],
            %{"foo" => "bar"}
          ]
      }

      result = presigned_json(upload) |> Jason.decode!()

      for condition <- upload.additional_conditions do
        assert condition in extract_from_policy(result, "conditions")
      end
    end

    test "presigned_json with expiration", %{upload: upload} do
      upload = %{upload | expiration: DateTime.from_naive!(~N[2020-01-01 00:00:00], "Etc/UTC")}

      result = presigned_json(upload) |> Jason.decode!()
      assert extract_from_policy(result, "expiration") == "2017-01-01T01:00:00Z"
    end

    @tag security_token: "test_security_token"
    test "presigned_json with security_token", %{upload: upload} do
      result = presigned_json(upload) |> Jason.decode!()
      assert result |> get("url") == "https://s3-bucket.s3.us-east-1.amazonaws.com"
      credentials = result |> get("credentials")
      assert credentials |> get("acl") == "public-read"
      assert credentials |> get("key") == "path/in/bucket/file.jpg"
      assert credentials |> get("policy") |> String.slice(0..9) == "eyJleHBpcm"
      assert credentials |> get("x-amz-algorithm") == "AWS4-HMAC-SHA256"
      assert credentials |> get("x-amz-credential") == "123abc/20170101/us-east-1/s3/aws4_request"
      assert credentials |> get("x-amz-date") == "20170101T000000Z"

      assert credentials |> get("x-amz-signature") ==
               "f55c2d2edc56456cd9f275d83845df030c9ea03399f636c9e2cb2da7bf3e03fd"

      assert credentials |> get("x-amz-security-token") ==
               Application.get_env(:ex_aws, :security_token)
    end

    defp extract_from_policy(result, key) do
      result
      |> get_in(~w(credentials policy))
      |> Base.decode64!()
      |> Jason.decode!()
      |> Map.fetch!(key)
    end
  end
end
