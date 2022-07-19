# frozen_string_literal: true

require 'datadog/statsd'
require_relative './config'
require_relative './aws_helper'

# Records timeliness of data-processing tasks' results on S3
class DataFreshness
  S3_LOCATIONS = {
    artist_career_stage: { bucket: 'artsy-cinder-production', prefix: 'builds/ArtistCareerStage/' },
    artist_gene_value: { bucket: 'artsy-cinder-production', prefix: 'builds/ArtistGeneValue/' },
    artist_related_genes: { bucket: 'artsy-cinder-production', prefix: 'builds/ArtistRelatedGenes/' },
    artist_similarity: { bucket: 'artsy-cinder-production', prefix: 'builds/ArtistSimilarity/' },
    artist_trending: { bucket: 'artsy-cinder-production', prefix: 'builds/ArtistTrending/' },
    artwork_gene_value: { bucket: 'artsy-cinder-production', prefix: 'builds/ArtworkGeneValue/' },
    artwork_iconicity: { bucket: 'artsy-cinder-production', prefix: 'builds/ArtworkIconicity/' },
    artwork_merchandisability: { bucket: 'artsy-cinder-production', prefix: 'builds/ArtworkMerchandisability/' },
    cf_artwork_similarity: { bucket: 'artsy-cinder-production', prefix: 'builds/CFArtworkSimilarity/' },
    contemporary_artist_similarity: { bucket: 'artsy-cinder-production',
                                      prefix: 'builds/ContemporaryArtistSimilarity/' },
    gene_partitioned_artist_trending: { bucket: 'artsy-cinder-production',
                                        prefix: 'builds/GenePartitionedArtistTrending/' },
    gene_similarity: { bucket: 'artsy-cinder-production', prefix: 'builds/GeneSimilarity/' },
    homefeed_artist_reco: { bucket: 'artsy-recommendations', prefix: 'homefeed/artist_reco.csv' },
    homefeed_artwork_reco: { bucket: 'artsy-recommendations', prefix: 'homefeed/artwork_reco.csv' },
    sitemaps: { bucket: 'artsy-sitemaps', prefix: 'sitemap-artist-series' }, # This is because in hue artist series is the last task to run in the chained sitemap tasks
    tag_count: { bucket: 'artsy-cinder-production', prefix: 'builds/TagCount/' },
    trending_score: { bucket: 'artsy-recommendations', prefix: 'trending_score/' },
    user_artwork_suggestions: { bucket: 'artsy-cinder-production', prefix: 'builds/UserArtworkSuggestions/' },
    user_genome: { bucket: 'artsy-cinder-production', prefix: 'builds/UserGenome/' },
    user_price_preference: { bucket: 'artsy-cinder-production', prefix: 'builds/UserPricePreference/' },
    candela_email_batches: { bucket: 'artsy-data', prefix: 'reports/candela.email_batches/' },
    candela_emails: { bucket: 'artsy-data', prefix: 'reports/candela.emails/' },
    causality_calculated_events: { bucket: 'artsy-data', prefix: 'reports/causality.calculated_events/' },
    causality_events: { bucket: 'artsy-data', prefix: 'reports/causality.events/' },
    causality_lot_states: { bucket: 'artsy-data', prefix: 'reports/causality.lot_states/' },
    convection_assets: { bucket: 'artsy-data', prefix: 'reports/convection.assets/' },
    convection_notes: { bucket: 'artsy-data', prefix: 'reports/convection.notes/' },
    convection_offers: { bucket: 'artsy-data', prefix: 'reports/convection.offers/' },
    convection_partners: { bucket: 'artsy-data', prefix: 'reports/convection.partners/' },
    convection_partner_submissions: { bucket: 'artsy-data', prefix: 'reports/convection.partner_submissions/' },
    convection_submissions: { bucket: 'artsy-data', prefix: 'reports/convection.submissions/' },
    convection_users: { bucket: 'artsy-data', prefix: 'reports/convection.users/' },
    diffusion_lots: { bucket: 'artsy-data', prefix: 'reports/diffusion.lots/' },
    diffusion_source_lots: { bucket: 'artsy-data', prefix: 'reports/diffusion.source_lots/' },
    exchange_admin_notes: { bucket: 'artsy-data', prefix: 'reports/exchange_production.admin_notes/' },
    exchange_fraud_reviews: { bucket: 'artsy-data', prefix: 'reports/exchange_production.fraud_reviews/' },
    exchange_fulfillments: { bucket: 'artsy-data', prefix: 'reports/exchange_production.fulfillments/' },
    exchange_line_item_fulfillments: { bucket: 'artsy-data', prefix: 'reports/exchange_production.line_item_fulfillments/' },
    exchange_line_items: { bucket: 'artsy-data', prefix: 'reports/exchange_production.line_items/' },
    exchange_offers: { bucket: 'artsy-data', prefix: 'reports/exchange_production.offers/' },
    exchange_orders: { bucket: 'artsy-data', prefix: 'reports/exchange_production.orders/' },
    exchange_shipments: { bucket: 'artsy-data', prefix: 'reports/exchange_production.shipments/' },
    exchange_shipping_quote_requests: { bucket: 'artsy-data', prefix: 'reports/exchange_production.shipping_quote_requests/' },
    exchange_shipping_quotes: { bucket: 'artsy-data', prefix: 'reports/exchange_production.shipping_quotes/' },
    exchange_state_histories: { bucket: 'artsy-data', prefix: 'reports/exchange_production.state_histories/' },
    exchange_transactions: { bucket: 'artsy-data', prefix: 'reports/exchange_production.transactions/' },
    impulse_assessments: { bucket: 'artsy-data', prefix: 'reports/impulse_assessments/' },
    impulse_conversation_items: { bucket: 'artsy-data', prefix: 'reports/impulse.conversation_items/' },
    impulse_conversations: { bucket: 'artsy-data', prefix: 'reports/impulse.conversations/' },
    impulse_messages: { bucket: 'artsy-data', prefix: 'reports/impulse.messages/' },
    gravity_account_activities: { bucket: 'artsy-data', prefix: 'reports/gravity.account_activies/' },
    gravity_account_requests: { bucket: 'artsy-data', prefix: 'reports/gravity.account_requests/' },
    gravity_artists: { bucket: 'artsy-data', prefix: 'reports/gravity.artists/' },
    gravity_artist_series_artworks: { bucket: 'artsy-data', prefix: 'reports/gravity.artist_series_artworks/' },
    gravity_artwork_versions: { bucket: 'artsy-data', prefix: 'reports/gravity.artwork_versions/' },
    gravity_artworks: { bucket: 'artsy-data', prefix: 'reports/gravity.artworks/' },
    gravity_bids: { bucket: 'artsy-data', prefix: 'reports/gravity.bids/' },
    gravity_bidder_positions: { bucket: 'artsy-data', prefix: 'reports/gravity.bidder_positions/' },
    gravity_bidders: { bucket: 'artsy-data', prefix: 'reports/gravity.bidders/' },
    gravity_blocked_emails: { bucket: 'artsy-data', prefix: 'reports/gravity.blocked_emails/' },
    gravity_credit_cards: { bucket: 'artsy-data', prefix: 'reports/gravity.credit_cards/' },
    gravity_collected_artworks: { bucket: 'artsy-data', prefix: 'reports/gravity.collected_artworks/' },
    gravity_collector_profiles: { bucket: 'artsy-data', prefix: 'reports/gravity.collector_profiles/' },
    gravity_collections: { bucket: 'artsy-data', prefix: 'reports/gravity.collections/' },
    gravity_commission_exemptions: { bucket: 'artsy-data', prefix: 'reports/gravity.commission_exemptions/' },
    gravity_edition_sets: { bucket: 'artsy-data', prefix: 'reports/gravity.edition_sets/' },
    gravity_fair_organizers: { bucket: 'artsy-data', prefix: 'reports/gravity.fair_organizers/' },
    gravity_fairs: { bucket: 'artsy-data', prefix: 'reports/gravity.fairs/' },
    gravity_follow_artists: { bucket: 'artsy-data', prefix: 'reports/gravity.follow_artists/' },
    gravity_identity_verifications: { bucket: 'artsy-data', prefix: 'reports/gravity.identity_verifications/' },
    gravity_inquiry_requests: { bucket: 'artsy-data', prefix: 'reports/gravity.inquiry_requests/' },
    gravity_jumio_scan_references: { bucket: 'artsy-data', prefix: 'reports/gravity.jumio_scan_references/' },
    gravity_lot_events: { bucket: 'artsy-data', prefix: 'reports/gravity.lot_events' },
    gravity_lots: { bucket: 'artsy-data', prefix: 'reports/gravity.lots/' },
    gravity_merchant_accounts: { bucket: 'artsy-data', prefix: 'reports/gravity.merchant_accounts/' },
    gravity_offer_actions: { bucket: 'artsy-data', prefix: 'reports/gravity.offer_actions/' },
    gravity_offer_emails: { bucket: 'artsy-data', prefix: 'reports/gravity.offer_emails/' },
    gravity_partner_artists: { bucket: 'artsy-data', prefix: 'reports/gravity.partner_artists/' },
    gravity_partner_locations: { bucket: 'artsy-data', prefix: 'reports/gravity.partner_locations/' },
    gravity_partners: { bucket: 'artsy-data', prefix: 'reports/gravity.partners/' },
    gravity_partner_show_artworks: { bucket: 'artsy-data', prefix: 'reports/gravity.partner_show_artworks/' },
    graviyt_partner_shows: { bucket: 'artsy-data', prefix: 'reports/gravity.partner_shows/' },
    gravity_partner_subscription_charges: { bucket: 'artsy-data', prefix: 'reports/gravity.partner_subscription_charges/' },
    gravity_partner_subscription_charge_line_items: { bucket: 'artsy-data', prefix: 'reports/gravity.partner_subscription_charge_line_items/' },
    gravity_partner_subscriptions: { bucket: 'artsy-data', prefix: 'reports/gravity.partner_subscriptions/' },
    gravity_profiles: { bucket: 'artsy-data', prefix: 'reports/gravity.profiles/' },
    gravity_purchases: { bucket: 'artsy-data', prefix: 'reports/gravity.purchases/' },
    gravity_representatives: { bucket: 'artsy-data', prefix: 'reports/gravity.representatives/' },
    gravity_resource_notes: { bucket: 'artsy-data', prefix: 'reports/gravity.resource_notes/' },
    gravity_sales: { bucket: 'artsy-data', prefix: 'reports/gravity.sales/' },
    gravity_sale_artworks: { bucket: 'artsy-data', prefix: 'reports/gravity.sale_artworks/' },
    gravity_search_criteria: { bucket: 'artsy-data', prefix: 'reports/gravity.search_criteria/' },
    gravity_second_factors: { bucket: 'artsy-data', prefix: 'reports/gravity.second_factors/' },
    gravity_user_interests: { bucket: 'artsy-data', prefix: 'reports/gravity.user_interests/' },
    gravity_users: { bucket: 'artsy-data', prefix: 'reports/gravity.users/' },
    gravity_user_search_criteria: { bucket: 'artsy-data', prefix: 'reports/gravity.user_search_criteria/' },
    gravity_viewing_room_artworks: { bucket: 'artsy-data', prefix: 'reports/gravity.viewing_room_artworks/' },
    gravity_viewing_rooms: { bucket: 'artsy-data', prefix: 'reports/gravity.viewing_rooms/' },
    positron_articles: { bucket: 'artsy-data', prefix: 'reports/positron.articles/' }
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
      warn "Recording data_freshness for #{key} as #{last_modified} with an age of #{age}"
      statsd.gauge "data_freshness.#{key}", age # seconds
    end
  end

  def statsd
    @statsd ||= Datadog::Statsd.new(Config.values[:dd_agent_host])
  end
end
