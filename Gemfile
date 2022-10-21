# frozen_string_literal: true

source 'https://rubygems.org'

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

gem 'activesupport'
gem 'aws-sdk-s3' # freshness of data-processing results
gem 'aws-sdk-ec2' # spot price
gem 'base64'
gem 'dogstatsd-ruby'
gem 'json'
gem 'jwt'
gem 'octokit' # release metrics
gem 'pg' # merge data into redshift
gem 'rake'
gem 'rubocop'

group :test do
  gem 'rspec'
end

group :development, :test do
  gem 'byebug'
end
