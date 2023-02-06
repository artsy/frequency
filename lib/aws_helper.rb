require 'aws-sdk-ec2'
require 'aws-sdk-s3'
require 'csv'
require 'zlib'
require_relative './config'

class AwsHelper
  def self.ec2_client
    @ec2_client ||= Aws::EC2::Client.new(
      region: Config.values[:aws_region],
      access_key_id: Config.values[:aws_access_key_id],
      secret_access_key: Config.values[:aws_secret_access_key]
    )
  end

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

  def self.upload_csv_to_s3(bucket, key, headers, data, client = AwsHelper.s3_client)
    $stderr.puts "Uploading to #{bucket} #{key}..."
    s3_object = Aws::S3::Object.new(bucket, key, client: client)
    s3_object.upload_stream(tempfile: true) do |s3_stream|
      s3_stream.binmode
      Zlib::GzipWriter.wrap(s3_stream) do |gzw|
        CSV(gzw, headers: headers, write_headers: true) do |csv|
          data.each { |row| csv << row }
        end
      end
    end
    s3_object
  end
end
