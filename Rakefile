# frozen_string_literal: true

begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec)
rescue LoadError
end

desc 'run both metrics tasks hourly'
task hourly: ['record:hourly_release_metrics', 'record:data_freshness', 'record:image_latency', 'record:spot_price']

namespace :record do
  desc 'Record hourly release.first_commit and release.pull_request_age metrics to statsd'
  task :hourly_release_metrics do
    require './lib/release_metrics'
    ReleaseMetrics.record_hourly_metrics
  end

  desc 'Record timeliness of data-processing results on S3'
  task :data_freshness do
    require './lib/data_freshness'
    DataFreshness.record_metrics
  end

  desc 'Record latency of image transformations'
  task :image_latency do
    require './lib/image_latency'
    ImageLatency.record_metrics
  end

  desc 'Record AWS Spot instances price'
  task :spot_price do
    require './lib/spot_price'
    SpotPrice.record_metrics
  end
end

desc 'scan k8s configmaps for expiring JWT tokens'
task :scan_tokens do
  require './lib/token_scanner'
  TokenScanner.new.run
end

namespace :commits do
  task :load do
    require './lib/commits_loader'
    CommitsLoader.load_recent_commits
  end
end
