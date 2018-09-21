# S3DirectUpload 
## with Authentication via Ex AWS
Pre-signed S3 upload helper for client-side multipart POSTs in Elixir.

[Browser-Based Upload using HTTP POST (Using AWS Signature Version 4)](http://docs.aws.amazon.com/AmazonS3/latest/API/sigv4-post-example.html)

[Task 3: Calculate the Signature for AWS Signature Version 4](http://docs.aws.amazon.com/general/latest/gr/sigv4-calculate-signature.html)

## Motivation
This is a fork and re-work of the original by @akappen, with a change to how the AWS Access ID and AWS Secret Key are 
identified. The original required them provided in config, which precluded the use of Instance Role, which contain 
temporary credentials. This fork attempts to use Ex AWS way of config and authentication, which would permit the use of 
instance Roles.

## Installation

S3DirectUpload can be installed by adding `s3_direct_upload` to your
list of dependencies in `mix.exs` and then running `mix deps.get`:

```elixir
def deps do
  [{:ex_aws_s3_direct_upload, "~> 1.0.0"}]
end
```

See https://github.com/ex-aws/ex_aws#aws-key-configuration for details of custom configurations. The default configuration should suffice.

## Documentation

[S3DirectUpload docs](https://hexdocs.pm/ex_aws_s3_direct_upload).
