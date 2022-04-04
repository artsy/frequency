# frozen_string_literal: true

require 'json'
require 'jwt'
require 'base64'

# Alert about JWT-style tokens approaching expiration dates
class TokenScanner
  # warn threshold in days
  WARN_THRESHOLD = 30

  # Regex pattern to match JWT like strings
  # translation:
  #   with non-capturing group capture any word character (\w) and hyphens followed by . exactly 2 times
  #   then capture any word character (\w) and hyphens until end of line
  #   like: xxx.xxx.xxx, -xx.x-x-x.xx-, etc...
  JWT_REGEX = /^(?:[\w-]*\.){2}[\w-]*$/.freeze

  def initialize(context)
    @context = context
  end

  def config_maps
    JSON.parse(`kubectl --context #{@context} get configmaps -o json`)
  end

  # returns number of days left until expiration
  def get_days_left(exp)
    exp_time = Time.at(exp).utc
    current_time = Time.now.utc + (60 * 60 * 24)
    ((exp_time - current_time) / (60 * 60 * 24)).to_i
  end

  # jwt? returns true if the input is a JWT-style token
  def jwt?(value)
    # apply regex to value, this will filter out 'most' non-JWT values
    return unless JWT_REGEX.match?(value)
    # to ensure we have a valid JWT, split the value on . and test the header (first part in JWT before the first period)
    #   valid JWTs will be base64 encoded and have a header with 'alg' and 'typ'
    #   some JWTs may not have 'typ' so we test header for 'alg' instead
    return unless Base64.decode64(value.split('.').first).include?('alg')

    true
  end

  # check configmap data for JWT expiration dates
  # raise an error if the expiration date is within the warn threshold
  def run
    tokens_near_expiration = []

    config_maps['items'].each do |config_map|
      name = config_map['metadata']['name']

      next unless config_map.key?('data')

      config_map['data'].each do |key, value|
        next unless jwt?(value)

        decoded_jwt = JWT.decode(value, nil, false)

        next unless decoded_jwt[0].key?('exp')

        days_left = get_days_left(decoded_jwt[0]['exp'])
        tokens_near_expiration << [name, key, days_left] if days_left < WARN_THRESHOLD
      end
    end

    warn tokens_near_expiration.inspect

    # raise error if any tokens are near expiration
    raise 'Some tokens will expire soon' if tokens_near_expiration.any?
  end
end
