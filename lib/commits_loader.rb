# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext/numeric'
require 'active_support/core_ext/time'
require 'json'
require 'tempfile'
require 'csv'
require 'zlib'
require 'pg'
require_relative './github'
require_relative './aws_helper'

class CommitsLoader
  HEADERS = %i[object_id repository message_headline message author_name authored_date committed_date pushed_date]
  BUCKET = 'artsy-data'

  def self.load_recent_commits
    new.load_recent_commits
  end

  def initialize(since: 30.days.ago, _until: nil, org: "artsy")
    @since = since
    @until = _until
    @org = org
  end

  def load_recent_commits
    data = build_data
    s3_object = upload_to_s3(data)
    merge_into_warehouse(s3_object)
  end

  private

  def build_data
    data = []
    each_recently_pushed_repo do |repo|
      each_recently_pushed_commit(repo) do |commit|
        data << {
          object_id: commit.oid,
          repository: repo.name,
          message_headline: commit.messageHeadline,
          message: commit.message,
          author_name: commit.author.name,
          authored_date: commit.authoredDate,
          committed_date: commit.committedDate,
          pushed_date: commit.pushedDate
        }
      end
    end
    data
  end

  def upload_to_s3(data)
    key = "reports/engineering.commits/partial_#{Time.now.to_s(:number)}.csv.gz"
    $stderr.puts "Uploading to #{BUCKET} #{key}..."
    s3_object = Aws::S3::Object.new(BUCKET, key, client: AwsHelper.s3_client)
    s3_object.upload_stream(tempfile: true) do |s3_stream|
      s3_stream.binmode
      Zlib::GzipWriter.wrap(s3_stream) do |gzw|
        CSV(gzw, headers: HEADERS, write_headers: true) do |csv|
          data.each { |row| csv << row }
        end
      end
    end
    s3_object
  end

  def merge_into_warehouse(s3_object)
    pg = PG.connect(Config.values[:redshift_url])
    begin
      $stderr.puts "Loading recent data into warehouse..."
      pg.exec(merge_query(s3_object))
    ensure
      pg.close
    end
  end

  def each_recently_pushed_repo
    cursor = nil
    loop do
      response = Github.execute_query(repo_query(cursor))
      response.data.repositoryOwner.repositories.nodes.each do |repo|
        $stderr.puts "Processing repo: #{repo.name} #{repo.pushedAt}"
        return if Time.parse(repo.pushedAt) < @since

        yield repo
      end
      return unless response.data.repositoryOwner.repositories.pageInfo.hasNextPage
      cursor = response.data.repositoryOwner.repositories.pageInfo.endCursor
    end
  end

  def each_recently_pushed_commit(repo)
    cursor = nil
    loop do
      response = Github.execute_query(commit_query(repo, cursor))
      response.data.repository.defaultBranchRef.target.history.nodes.each do |commit|
        $stderr.puts "\tProcessing commit: #{commit.oid} on #{repo.name} (#{commit.committedDate})..."
        yield commit
      end
      return unless response.data.repository.defaultBranchRef.target.history.pageInfo.hasNextPage
      cursor = response.data.repository.defaultBranchRef.target.history.pageInfo.endCursor
    end
  end

  def repo_query(cursor)
    <<-QUERY
      query {
        repositoryOwner(login: #{@org.to_json}) {
          repositories(first: 100, orderBy: {direction: DESC, field: PUSHED_AT}#{", after: #{cursor.to_json}" if cursor}) {
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

  def commit_query(repo, cursor)
    <<-QUERY
      query {
        repository(owner: #{@org.to_json}, name: #{repo.name.to_json}) {
          defaultBranchRef {
            target {
              ... on Commit {
                history(first: 100, since: #{@since&.utc&.iso8601.to_json}, until: #{@until&.utc&.iso8601.to_json}#{", after: #{cursor.to_json}" if cursor}) {
                  pageInfo {
                    hasNextPage
                    endCursor
                  }
                  nodes {
                    messageHeadline
                    oid
                    message
                    author {
                      name
                      email
                      date
                    }
                    pushedDate
                    authoredDate
                    committedDate
                  }
                }
              }
            }
          }
        }
      }
    QUERY
  end

  def merge_query(s3_object)
    <<-SQL
      create temporary table commits_staged (like engineering.commits);

      copy commits_staged from 's3://#{s3_object.bucket.name}/#{s3_object.key}'
        with credentials '#{AwsHelper.credentials_for_sql}'
        csv
        ignoreheader 1
        emptyasnull
        acceptinvchars
        gzip
        timeformat 'auto'
        dateformat 'auto'
        truncatecolumns;

      begin transaction;

      delete from engineering.commits
      using commits_staged
      where engineering.commits.object_id = commits_staged.object_id;

      insert into engineering.commits
      select * from commits_staged;

      end transaction;

      drop table commits_staged;
    SQL
  end
end