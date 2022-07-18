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
    purchases: { bucket: 'artsy-data', prefix: 'reports/gravity.purchases/' },
    account_requests: { bucket: 'artsy-data', prefix: 'reports/gravity.account_requests/' },
    partner_subscription_charges: { bucket: 'artsy-data', prefix: 'reports/gravity.partner_subscription_charges/' },
    bidders: { bucket: 'artsy-data', prefix: 'reports/gravity.bidders/' },
    credit_cards: { bucket: 'artsy-data', prefix: 'reports/gravity.credit_cards/' },
    sale_artworks: { bucket: 'artsy-data', prefix: 'reports/gravity.sale_artworks/' },
    bidder_positions: { bucket: 'artsy-data', prefix: 'reports/gravity.bidder_positions/' },
    offer_emails: { bucket: 'artsy-data', prefix: 'reports/gravity.offer_emails/' },
    user_interests: { bucket: 'artsy-data', prefix: 'reports/gravity.user_interests/' },
    bids: { bucket: 'artsy-data', prefix: 'reports/gravity.bids/' },
    partner_subscription_charge_line_items: { bucket: 'artsy-data', prefix: 'reports/gravity.partner_subscription_charge_line_items/' },
    offer_actions: { bucket: 'artsy-data', prefix: 'reports/gravity.offer_actions/' },
    partner_shows: { bucket: 'artsy-data', prefix: 'reports/gravity.partner_shows/' },
    partner_artists: { bucket: 'artsy-data', prefix: 'reports/gravity.partner_artists/' },
    partner_show_artworks: { bucket: 'artsy-data', prefix: 'reports/gravity.partner_show_artworks/' },
    artists: { bucket: 'artsy-data', prefix: 'reports/gravity.artists/' },
    inquiry_requests: { bucket: 'artsy-data', prefix: 'reports/gravity.inquiry_requests/' },
    collector_profiles: { bucket: 'artsy-data', prefix: 'reports/gravity.collector_profiles/' },
    edition_sets: { bucket: 'artsy-data', prefix: 'reports/gravity.edition_sets/' },
    users: { bucket: 'artsy-data', prefix: 'reports/gravity.users/' },
    follow_artists: { bucket: 'artsy-data', prefix: 'reports/gravity.follow_artists/' },
    artwork_versions: { bucket: 'artsy-data', prefix: 'reports/gravity.artwork_versions/' },
    artworks: { bucket: 'artsy-data', prefix: 'reports/gravity.artworks/' },
    impulse_conversations: { bucket: 'artsy-data', prefix: 'reports/impulse.conversations/' },
    impulse_conversation_items: { bucket: 'artsy-data', prefix: 'reports/impulse.conversation_items/' },
    impulse_messages: { bucket: 'artsy-data', prefix: 'reports/impulse.messages/' },
    impulse_assessments: { bucket: 'artsy-data', prefix: 'reports/impulse_assessments/' },
    convection_assets: { bucket: 'artsy-data', prefix: 'reports/convection.assets/' },
    convection_offers: { bucket: 'artsy-data', prefix: 'reports/convection.offers/' },
    convection_partners: { bucket: 'artsy-data', prefix: 'reports/convection.partners/' },
    convection_partner_submissions: { bucket: 'artsy-data', prefix: 'reports/convection.partner_submissions/' },
    convection_submissions: { bucket: 'artsy-data', prefix: 'reports/convection.submissions/' },
    convection_users: { bucket: 'artsy-data', prefix: 'reports/convection.users/' },
    convection_notes: { bucket: 'artsy-data', prefix: 'reports/convection.notes/' },
    causality_high_bids: { bucket: 'artsy-data', prefix: 'reports/causality_high_bids/' },
    causality_calculated_events: { bucket: 'artsy-data', prefix: 'reports/causality.calculated_events/' },
    causality_events: { bucket: 'artsy-data', prefix: 'reports/causality.events/' },
    causality_lot_states: { bucket: 'artsy-data', prefix: 'reports/causality.lot_states/' },
    positron_articles: { bucket: 'artsy-data', prefix: 'reports/positron.articles/' },
    exchange_orders: { bucket: 'artsy-data', prefix: 'reports/exchange_orders/' },
    exchange_state_histories: { bucket: 'artsy-data', prefix: 'reports/exchange_state_histories/' },
    exchange_line_items: { bucket: 'artsy-data', prefix: 'reports/exchange_line_items/' },
    exchange_transactions: { bucket: 'artsy-data', prefix: 'reports/exchange_transactions/' },
    exchange_fulfillments: { bucket: 'artsy-data', prefix: 'reports/exchange_fulfillments/' },
    exchange_line_item_fulfillments: { bucket: 'artsy-data', prefix: 'reports/exchange_line_item_fulfillments/' },
    exchange_offers: { bucket: 'artsy-data', prefix: 'reports/exchange_offers/' },
    exchange_fraud_reviews: { bucket: 'artsy-data', prefix: 'reports/exchange_fraud_reviews/' },
    exchange_admin_notes: { bucket: 'artsy-data', prefix: 'reports/exchange_admin_notes/' },
    exchange_shipping_quote_requests: { bucket: 'artsy-data', prefix: 'reports/exchange_shipping_quote_requests/' },
    exchange_quotes: { bucket: 'artsy-data', prefix: 'reports/exchange_shipping_quotes/' },
    exchange_shipments: { bucket: 'artsy-data', prefix: 'reports/exchange_shipments/' },
    candela_email_batches: { bucket: 'artsy-data', prefix: 'reports/candela.email_batches/' },
    candela_emails: { bucket: 'artsy-data', prefix: 'reports/candela.emails/' },
    marketo_activity_types: { bucket: 'artsy-data', prefix: 'reports/marketo_activity_types/' },
    marketo_form_submissions: { bucket: 'artsy-data', prefix: 'reports/marketo_form_submissions/' },
    diffusion_lots_archive: { bucket: 'artsy-data', prefix: 'reports/diffusion.lots_archive/' },
    diffusion_lots: { bucket: 'artsy-data', prefix: 'reports/diffusion.lots/' },
    diffusion_source_lots_archive: { bucket: 'artsy-data', prefix: 'reports/diffusion.source_lots_archive/' },
    diffusion_source_lots: { bucket: 'artsy-data', prefix: 'reports/diffusion.source_lots/' },
    account_activies: { bucket: 'artsy-data', prefix: 'reports/gravity.account_activies/' },
    artist_series_artworks: { bucket: 'artsy-data', prefix: 'reports/gravity.artist_series_artworks/' },
    artist_series: { bucket: 'artsy-data', prefix: 'reports/gravity.artist_series/' },
    blocked_emails: { bucket: 'artsy-data', prefix: 'reports/gravity.blocked_emails/' },
    collected_artworks: { bucket: 'artsy-data', prefix: 'reports/gravity.collected_artworks/' },
    collections: { bucket: 'artsy-data', prefix: 'reports/gravity.collections/' },
    commission_exemptions: { bucket: 'artsy-data', prefix: 'reports/gravity.commission_exemptions/' },
    identity_verifications: { bucket: 'artsy-data', prefix: 'reports/gravity.identity_verifications/' },
    jumio_scan_references: { bucket: 'artsy-data', prefix: 'reports/gravity.jumio_scan_references/' },
    lots: { bucket: 'artsy-data', prefix: 'reports/gravity.lots/' },
    lot_events: { bucket: 'artsy-data', prefix: 'reports/gravity.lot_events' },
    rescource_notes: { bucket: 'artsy-data', prefix: 'reports/gravity.resource_notes'/ },
    search_criteria: { bucket: 'artsy-data', prefix: 'reports/gravity.search_criteria/' },
    second_factors: { bucket: 'artsy-data', prefix: 'reports/gravity.second_factors/' },
    user_search_criterias: { bucket: 'artsy-data', prefix: 'reports/gravity.user_search_criteria/' },
    viewing_room_artworks: { bucket: 'artsy-data', prefix: 'reports/gravity.viewing_room_artworks/' },
    viewing_rooms: { bucket: 'artsy-data', prefix: 'reports/gravity.viewing_rooms/' }
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
