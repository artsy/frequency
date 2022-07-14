# frozen_string_literal: true

require 'datadog/statsd'
require_relative './config'
require_relative './aws_helper'

# Records timeliness of extracts tasks' results on S3
class DataFreshness
  S3_LOCATIONS = {
    fair_organizers: { bucket: 'artsy-data', prefix: 'reports/gravity.fair_organizers/' },
    artist_series_artworks: { bucket: 'artsy-data', prefix: 'reports/gravity.partner_subscription_plans/' },
    merchant_accounts: { bucket: 'artsy-data', prefix: 'reports/gravity.merchant_accounts/' },
    sales: { bucket: 'artsy-data', prefix: 'reports/gravity.sales/' },
    fairs: { bucket: 'artsy-data', prefix: 'reports/gravity.fairs/' },
    profiles: { bucket: 'artsy-data', prefix: 'reports/gravity.profiles/' },
    representatives: { bucket: 'artsy-data', prefix: 'reports/gravity.representatives/' },
    partner_subscriptions: { bucket: 'artsy-data', prefix: 'reports/gravity.partner_subscriptions/' },
    partner_locations: { bucket: 'artsy-data', prefix: 'reports/gravity.partner_locations/' },
    partners: { bucket: 'artsy-data', prefix: 'reports/gravity.partners/' },
    purchases: { bucket: 'artsy-data', prefix: 'reports/gravity.purchases' },
    account_requests: { bucket: 'artsy-data', prefix: 'reports/gravity.account_requests' },
    partner_subscription_charges: { bucket: 'artsy-data', prefix: 'reports/gravity.partner_subscription_charges' },
    bidders: { bucket: 'artsy-data', prefix: 'reports/gravity.bidders' },
    credit_cards: { bucket: 'artsy-data', prefix: 'reports/gravity.credit_cards' },
    sale_artworks: { bucket: 'artsy-data', prefix: 'reports/gravity.sale_artworks' },
    bidder_positions: { bucket: 'artsy-data', prefix: 'reports/gravity.bidder_positions' },
    offer_emails: { bucket: 'artsy-data', prefix: 'reports/gravity.offer_emails' },
    user_interests: { bucket: 'artsy-data', prefix: 'reports/gravity.user_interests' },
    bids: { bucket: 'artsy-data', prefix: 'reports/gravity.bids' },
    partner_subscription_charge_line_items: { bucket: 'artsy-data', prefix: 'reports/gravity.partner_subscription_charge_line_items' },
    offer_actions: { bucket: 'artsy-data', prefix: 'reports/gravity.offer_actions' },
    partner_shows: { bucket: 'artsy-data', prefix: 'reports/gravity.partner_shows' },
    partner_artists: { bucket: 'artsy-data', prefix: 'reports/gravity.partner_artists' },
    partner_show_artworks: { bucket: 'artsy-data', prefix: 'reports/gravity.partner_show_artworks' },
    artists: { bucket: 'artsy-data', prefix: 'reports/gravity.artists' },
    inquiry_requests: { bucket: 'artsy-data', prefix: 'reports/gravity.inquiry_requests' },
    collector_profiles: { bucket: 'artsy-data', prefix: 'reports/gravity.collector_profiles' },
    edition_sets: { bucket: 'artsy-data', prefix: 'reports/gravity.edition_sets' },
    users: { bucket: 'artsy-data', prefix: 'reports/gravity.users' },
    follow_artists: { bucket: 'artsy-data', prefix: 'reports/gravity.follow_artists' },
    artwork_versions: { bucket: 'artsy-data', prefix: 'reports/gravity.artwork_versions' },
    artworks: { bucket: 'artsy-data', prefix: 'reports/gravity.artworks' },
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
