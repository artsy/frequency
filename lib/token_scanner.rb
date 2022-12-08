# frozen_string_literal: true

require 'json'
require 'jwt'
require 'base64'

# TokenScanner scans configmaps for JWT-style tokens and logs approaching or expired number of days
class TokenScanner
  # warn threshold in days
  WARN_THRESHOLD = 30

  # Regex pattern to match JWT like strings:
  #   with non-capturing group, capture any word character (\w) and hyphens followed by . exactly 2 times
  #   then, capture any word character (\w) and hyphens until end of line
  #   like: xxx.xxx.xxx, -xx.x-x-x.xx-, etc...
  JWT_REGEX = /^(?:[\w-]*\.){2}[\w-]*$/.freeze

  def initialize
    @tokens = {
      production: [],
      staging: []
    }
  end

  def run
    @tokens.each do |context, results|
      scan_configmaps(context, results)
    end

    return unless @tokens[:production].any? || @tokens[:staging].any?

    log_expirations
    raise 'Some tokens will expire soon or have expired!'
  end

  private

  def scan_configmaps(context, results)
    config_maps(context)['items'].each do |config_map|
      name = config_map['metadata']['name']
      next unless config_map.key?('data')

      config_map['data'].each do |key, value|
        next unless jwt?(value)

        decoded_jwt = JWT.decode(value, nil, false)
        next unless decoded_jwt[0].key?('exp')

        days_left = get_days_left(decoded_jwt[0]['exp'])

        aud_id = decoded_jwt[0]['aud']

        sub_id = decoded_jwt[0]['subject_application']

        results << [name, key, days_left, aud_id, sub_id] if days_left < WARN_THRESHOLD
      end
    end
  end

  def config_maps(context)
    JSON.parse(`kubectl --context #{context} get configmaps -o json`)
  end

  # get_days_left returns the number of days left until expiration (from today)
  def get_days_left(exp)
    exp_time = Time.at(exp).utc
    current_time = Time.now.utc
    ((exp_time - current_time) / (60 * 60 * 24)).to_i
  end

  # jwt? returns true if the input is a JWT-style token otherwise false
  def jwt?(value)
    return false unless JWT_REGEX.match?(value)

    # to further validate JWT, split the value on . and test the header (first part in JWT, before the first period)
    #   JWT header should be base64 encoded and contain an 'alg' and 'typ' keys
    #   some JWTs may not have 'typ' so we test header for 'alg' instead
    return false unless Base64.strict_decode64(value.split('.').first).include?('alg')

    true
  rescue ArgumentError
    false
  end

  def log_expirations
    puts 'START'
    @tokens.each do |context, results|
      next unless results.any?

      puts "Context: #{context}"
      results.each do |result|
        expiration = result[2].positive? ? "expires-in: #{result[2]} days" : "expired: #{result[2].abs} days ago"
        puts "\tconfigmap: #{result[0]}"
        puts "\t\t key: #{result[1]}, #{expiration}."
        puts "\t\t audience_id = #{result[3]}, subject_id = #{result[4]}"
      end
    end
    puts 'END'
  end
end
