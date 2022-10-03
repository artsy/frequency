# frozen_string_literal: true

require 'securerandom'
require 'datadog/statsd'
require_relative './config'

# Records timeliness of data-processing tasks' results on S3
class ImageLatency
  IMAGE_URL = 'https://d7hftxdivxxvm.cloudfront.net/?resize_to=fit&src=https%3A%2F%2Fd32dm0rphc51dk.cloudfront.net%2FMQ5HiQrrZ-vOIpkEVNBomg%2Flarge.jpg&width=890&height=1186&quality=80'
  ACCEPT_HEADER = 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8'

  def self.record_metrics
    new.record_metrics
  end

  def record_metrics
    url = "#{IMAGE_URL}&rand=#{SecureRandom.hex}" # append random param to ensure CDN cache miss
    command = "curl -H 'Accept: #{ACCEPT_HEADER}' '#{url}'"
    warn "Running: #{command}"
    start = Time.now
    `#{command}`
    latency = Time.now - start
    warn "Recording image_latency as #{latency}"
    statsd.gauge "image_latency", latency # seconds
  end

  def statsd
    @statsd ||= Datadog::Statsd.new(Config.values[:dd_agent_host])
  end
end
