require 'aws-sdk-s3'
require_relative './config'

class AwsHelper
  def self.s3_client
    @s3_client ||= Aws::S3::Client.new(
      region: Config.values[:aws_region],
      access_key_id: Config.values[:aws_access_key_id],
      secret_access_key: Config.values[:aws_secret_access_key]
    )
  end

  def self.credentials_for_sql
    [
      "aws_access_key_id=#{Config.values[:aws_access_key_id]}",
      "aws_secret_access_key=#{Config.values[:aws_secret_access_key]}"
    ].join(';')
  end
end
