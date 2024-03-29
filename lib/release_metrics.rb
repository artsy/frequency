# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext/numeric'
require 'active_support/core_ext/time'
require 'datadog/statsd'
require_relative './config'
require_relative './github'

# Records cycle time metrics for releases in the last hour.
class ReleaseMetrics
  def self.record_hourly_metrics
    new.record_hourly_metrics
  end

  def record_hourly_metrics
    t = 1.hour.ago.utc
    query = "org:artsy is:pr is:merged base:release merged:#{t.beginning_of_hour.iso8601}..#{t.end_of_hour.iso8601}"
    Github.client.search_issues(query, page: 1, per_page: 100).items.each do |release_pr|
      # record time span between PR open and production release
      pull_requests_for_release(release_pr).map do |pr|
        age_s = release_pr.closed_at - Time.parse(pr.createdAt)
        warn "Recording pull request age #{age_s} for pull request #{pr.url} in release #{release_pr.html_url}"
        statsd.timing 'release.pull_request_age', age_s * 1000 # milliseconds
      end

      repo = release_pr.repository_url.split('/')[-2..].join('/')
      first_commit = Github.client.pull_request_commits(repo, release_pr.number, per_page: 1).first
      next unless first_commit

      cycle_time = release_pr.closed_at - first_commit.commit.author.date
      warn "Recording cycle time #{cycle_time} for release #{release_pr.html_url}"
      statsd.timing 'release.first_commit', cycle_time * 1000 # milliseconds
    end
  end

  def statsd
    @statsd ||= Datadog::Statsd.new(Config.values[:dd_agent_host])
  end

  def pull_requests_for_release(issue)
    query = <<-QUERY
      query {
        node(id: "#{issue.node_id}") {
          ...on PullRequest {
            commits(first: 100) {
              edges {
                node {
                  ...on PullRequestCommit {
                    commit {
                      associatedPullRequests(first:1) {
                        edges {
                          node {
                            url
                            createdAt
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    QUERY

    response = Github.execute_query(query)
    if response.errors&.length&.positive?
      warn "Error: Retrieving pull requests from Github graphql API: #{response.errors}"
    end
    response.data.node.commits.edges.flat_map do |e|
      e.node.commit.associatedPullRequests.map { |_k, v| v.first.node }
    end.uniq(&:url)
  end
end
