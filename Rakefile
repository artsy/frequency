# frozen_string_literal: true

begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec)
rescue LoadError
end

desc 'run both metrics tasks hourly'
task hourly: ['record:hourly_release_metrics', 'record:data_freshness']

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
end

desc 'scan tokens'
task :scan_tokens do
  require './lib/token_scanner'
  TokenScanner.new.run
end
