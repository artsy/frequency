require_relative './config'

# Alert about JWT-style tokens approaching expiration dates
class TokenScanner
  def run
    tokens_near_expiration = []

    get_config_maps.each do |config_map|
      name = config_map # ...
      config_map['data'].each do |key, value| # ...
        next unless value.matches(JWT_REGEX)

        expiration = attempt_to_decode_expiration
        next unless expiration

        tokens_near_expiration << [config_map_name, key] if expiration < time_window
      end
    end

    $stderr.puts tokens_near_expiration.inspect

    # exit non-zero or:
    raise "Some tokens will expire soon" if tokens_near_expiration.any?
  end

  def get_config_maps
    JSON.parse(`kubectl --context staging get configmaps -o json`)
  end
end

