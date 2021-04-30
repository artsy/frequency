require 'datadog/statsd'
require 'aws-sdk-s3'
require_relative './config'

# Records timeliness of data-processing tasks' results on S3
class DataFreshness
  S3_LOCATIONS = [
    user_artwork_suggestions: { bucket: 'artsy-cinder-production', path: 'builds/UserArtworkSuggestions/' }
  ]

  def self.record_metrics
    new.record_metrics
  end

  def record_metrics
    $stderr.puts s3_client.list_buckets.inspect
    S3_LOCATIONS.each do |key, s3|

      # find age of newest S3 object matching path on bucket
      statsd.gauge "data_freshness.#{key}", age # seconds
    end
  end

  def statsd
    @statsd ||= Datadog::Statsd.new(Config.values[:dd_agent_host])
  end

  def s3_client
    @s3_client ||= Aws::S3::Client.new(
      access_key_id: Config.values[:aws_access_key_id],
      secret_access_key: Config.values[:aws_secret_access_key]
    )
  end
end
