class Config
  def self.values
    @values ||= load_config
  end

  def self.load_config
    {
      aws_access_key_id: ENV['AWS_ACCESS_KEY_ID'],
      aws_secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
      dd_agent_host: ENV['DD_AGENT_HOST'],
      github_access_token: ENV['GITHUB_ACCESS_TOKEN']
    }.tap do |config|
      $stderr.puts "Loading config #{config.map{|k,v| [k, v&.gsub(/.(?<=.{3})/,'*')].join(':') }.join(', ')}"
    end
  end
end
