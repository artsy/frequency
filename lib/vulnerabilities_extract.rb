# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext/numeric'
require 'active_support/core_ext/time'
require 'json'
require_relative './github'
require_relative './aws_helper'

class VulnerabilitiesExtract
  HEADERS = %i[repository vulnerability_id package created_at dismissed_at fixed_at state severity description]
  BUCKET = Config.values[:extracts_bucket]

  def self.extract_vulnerabilities
    new.extract_vulnerabilities
  end

  def initialize(org: 'artsy')
    @org = org
  end

  def extract_vulnerabilities
    data = build_data
    AwsHelper.upload_csv_to_s3(
      BUCKET,
      "extracts/full/engineering/vulnerabilities/export_#{Time.now.to_s(:number)}/extract.csv.gz",
      HEADERS,
      data
    )
  end

  private

  def build_data
    data = []
    each_repo do |repo|
      each_vulnerability(repo) do |vuln|
        data << {
          repository: repo.name,
          vulnerability_id: vuln.id,
          package: vuln.securityVulnerability.package.name,
          created_at: vuln.createdAt,
          dismissed_at: vuln.dismissedAt,
          fixed_at: vuln.fixedAt,
          state: vuln.state,
          severity: vuln.securityVulnerability.severity,
          description: vuln.securityVulnerability.advisory.description
        }
      end
    end
    data
  end

  def each_repo
    cursor = nil
    loop do
      response = Github.execute_query(repo_query(cursor))
      response.data.repositoryOwner.repositories.nodes.each do |repo|
        warn "Processing repo: #{repo.name} #{repo.pushedAt}"
        yield repo
      end
      return unless response.data.repositoryOwner.repositories.pageInfo.hasNextPage

      cursor = response.data.repositoryOwner.repositories.pageInfo.endCursor
    end
  end

  def each_vulnerability(repo)
    cursor = nil
    loop do
      response = Github.execute_query(vulnerability_query(repo, cursor))
      response.data.repository.vulnerabilityAlerts.nodes.each do |vuln|
        warn "\tProcessing vulnerability alert: #{vuln.id} on #{repo.name}..."
        yield vuln
      end
      return unless response.data.repository.vulnerabilityAlerts.pageInfo.hasNextPage

      cursor = response.data.repository.vulnerabilityAlerts.pageInfo.endCursor
    end
  end

  def repo_query(cursor)
    <<-QUERY
      query {
        repositoryOwner(login: #{@org.to_json}) {
          repositories(first: 100, orderBy: {direction: DESC, field: PUSHED_AT}#{if cursor
                                                                                   ", after: #{cursor.to_json}"
                                                                                 end}) {
            pageInfo {
              hasNextPage
              endCursor
            }
            nodes {
              name
              pushedAt
            }
          }
        }
      }
    QUERY
  end

  def vulnerability_query(repo, cursor)
    <<-QUERY
      query {
        repository(owner: #{@org.to_json}, name: #{repo.name.to_json}) {
          vulnerabilityAlerts(first: 100#{", after: #{cursor.to_json}" if cursor}) {
            nodes {
              id
              createdAt
              dismissedAt
              fixedAt
              state
              securityVulnerability {
                package {
                  name
                }
                advisory {
                  description
                }
                severity
              }
            }
            pageInfo {
              endCursor
              hasNextPage
            }
          }
        }
      }
    QUERY
  end
end
