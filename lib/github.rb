require 'octokit'
require 'json'
require_relative './config'

class Github
  # contruct and memoize a client object
  def self.client
    @client ||= Octokit::Client.new(access_token: Config.values[:github_access_token])
  end

  def self.execute_query(query)
    response = client.post '/graphql', { query: query }.to_json
    if response.errors&.length&.positive?
      warn "Error: Retrieving results from Github graphql API: #{response.errors}"
    end
    response
  end
end
