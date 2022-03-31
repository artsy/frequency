require 'json'
require 'jwt'
require_relative './config'

# Alert about JWT-style tokens approaching expiration dates
class TokenScanner
  JWT_REGEX = /^(?:[\w-]*\.){2}[\w-]*$/.freeze
  JWT_REGEX1 = /^(?:[\w-]*\.){2}[\w-]+{6,}$/.freeze

  def run
    tokens_near_expiration = []

    puts get_config_maps["items"].length

    get_config_maps["items"].each do |config_map|
      name = config_map["metadata"]["name"]

      next unless config_map.has_key?("data")

      hits = []
      config_map['data'].each do |key, value|
        next unless JWT_REGEX1.match?(value)
        next unless value.split('.').first.length > 5

        puts JWT.decode value, nil, false
        next
        hits << "#{key} : #{value}"
        next
        expiration = attempt_to_decode_expiration
        next unless expiration

        tokens_near_expiration << [config_map_name, key] if expiration < time_window
      end

      next unless hits.length.positive?

      puts
      puts name, "=========================="
      hits.each do |hit| puts hit end

    end

    $stderr.puts tokens_near_expiration.inspect

    # exit non-zero or:
    raise "Some tokens will expire soon" if tokens_near_expiration.any?
  end

  def get_config_maps
    JSON.parse(`kubectl --context staging get configmaps -o json`)
  end
end

