defmodule ExAws.S3.DirectUpload.Mixfile do
  use Mix.Project

  def project do
    [
      app: :ex_aws_s3_direct_upload,
      version: "0.0.1",
      elixir: "~> 1.5",
      elixirc_paths: elixirc_paths(Mix.env()),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      source_url: "https://github.com/mtarnovan/ex_aws_s3_direct_upload",
      description: description(),
      package: package(),
      deps: deps()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Configuration for the OTP application
  def application do
    [extra_applications: [:logger]]
  end

  # Dependencies
  defp deps do
    [
      {:jason, "~> 1.1"},
      {:ex_aws_s3, "~> 2.0"},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    Pre-signed S3 upload helper for client-side multipart POSTs, using ExAWS for authentication. Allows use of Instance Role for authentication.
    """
  end

  defp package do
    [
      name: :ex_aws_s3_direct_upload,
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      authors: ["Andrew Kappen", "Piotr Steininger"],
      maintainers: ["Piotr Steininger"],
      licenses: ["Apache 2.0"],
      links: %{
        "GitHub" => "https://github.com/laborvoices/ex_aws_s3_direct_upload",
        "S3 Direct Uploads With Ember And Phoenix" =>
          "http://haughtcodeworks.com/blog/software-development/s3-direct-uploads-with-ember-and-phoenix/",
        "Browser-Based Upload using HTTP POST (Using AWS Signature Version 4)" =>
          "http://docs.aws.amazon.com/AmazonS3/latest/API/sigv4-post-example.html",
        "Task 3: Calculate the Signature for AWS Signature Version 4" =>
          "http://docs.aws.amazon.com/general/latest/gr/sigv4-calculate-signature.html"
      }
    ]
  end
end
