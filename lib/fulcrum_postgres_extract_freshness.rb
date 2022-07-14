# frozen_string_literal: true

require 'datadog/statsd'
require_relative './config'
require_relative './aws_helper'

# Records timeliness of extracts tasks' results on S3
class DataFreshness
  S3_LOCATIONS = {
    account_activies: { bucket: 'artsy-data', prefix: 'reports/gravity_account_activies/' },
    artist_series_artworks: { bucket: 'artsy-data', prefix: 'reports/gravity_artist_series_artworks/' },
    artist_series: { bucket: 'artsy-data', prefix: 'reports/gravity_artist_series/' },
    blocked_emails: { bucket: 'artsy-data', prefix: 'reports/gravity_blocked_emails/' },
    collected_artworks: { bucket: 'artsy-data', prefix: 'reports/gravity_collected_artworks/' },
    collections: { bucket: 'artsy-data', prefix: 'reports/gravity_collections/' },
    commission_exemptions: { bucket: 'artsy-data', prefix: 'reports/gravity_commission_exemptions/' },
    identity_verifications: { bucket: 'artsy-data', prefix: 'reports/gravity_identity_verifications/' },
    jumio_scan_references: { bucket: 'artsy-data', prefix: 'reports/gravity_jumio_scan_references/' },
    lots: { bucket: 'artsy-data', prefix: 'reports/gravity_lots/' },
    lot_events: { bucket: 'artsy-data', prefix: 'reports/gravity_lot_events' },
    rescource_notes: { bucket: 'artsy-data', prefix: 'reports/gravity_resource_notes' },
    search_criteria: { bucket: 'artsy-data', prefix: 'reports/gravity_search_criteria' },
    second_factors: { bucket: 'artsy-data', prefix: 'reports/gravity_second_factors' },
    user_search_criterias: { bucket: 'artsy-data', prefix: 'reports/gravity_user_search_criteria' },
    viewing_room_artworks: { bucket: 'artsy-data', prefix: 'reports/gravity_viewing_room_artworks' },
    viewing_rooms: { bucket: 'artsy-data', prefix: 'reports/gravity_viewing_rooms' }
  }.freeze

  def self.record_metrics
    new.record_metrics
  end

  def record_metrics
    S3_LOCATIONS.each do |key, s3|
      last_modified = AwsHelper.s3_client.list_objects(bucket: s3[:bucket], prefix: s3[:prefix]).flat_map do |response|
        response.contents.map(&:last_modified)
      end.max
      next unless last_modified

      age = Time.now - last_modified
      warn "Recording freshness for extract #{key} as #{last_modified} with an age of #{age}"
      statsd.gauge "postgres_extract_freshness.#{key}", age # seconds
    end
  end

  def statsd
    @statsd ||= Datadog::Statsd.new(Config.values[:dd_agent_host])
  end
end
