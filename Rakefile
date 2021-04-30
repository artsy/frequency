begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec)
rescue LoadError
end

namespace :record do
  desc 'Record hourly release.first_commit and release.pull_request_age metrics to statsd'
  task :hourly_release_metrics do
    require './lib/release_metrics'
    ReleaseMetrics.record_hourly_metrics
  end
end
