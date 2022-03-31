# frozen_string_literal: true

source "https://rubygems.org"

git_source(:github) {|repo_name| "https://github.com/#{repo_name}" }

gem 'activesupport'
gem 'dogstatsd-ruby'
gem 'octokit' # release metrics
gem 'rake'
gem 'aws-sdk-s3' # freshness of data-processing results
gem 'json'
gem 'jwt'

group :test do
  gem 'rspec'
end
