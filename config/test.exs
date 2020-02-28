use Mix.Config

# Test configuration
config :ex_aws,
  access_key_id: "123abc",
  secret_access_key: "abc123",
  security_token: nil,
  s3_direct_upload_date_util: ExAws.S3.DirectUpload.TestDateUtil
