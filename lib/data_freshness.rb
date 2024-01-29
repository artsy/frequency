# frozen_string_literal: true

require 'datadog/statsd'
require_relative './config'
require_relative './aws_helper'

# Records timeliness of data-processing tasks' results on S3
class DataFreshness
  S3_LOCATIONS = {
    artist_career_stage: { bucket: 'artsy-gravity-index-production', prefix: 'builds/ArtistCareerStage/' },
    artist_gene_value: { bucket: 'artsy-gravity-index-production', prefix: 'builds/ArtistGeneValue/' },
    artist_related_genes: { bucket: 'artsy-gravity-index-production', prefix: 'builds/ArtistRelatedGenes/' },
    artist_similarity: { bucket: 'artsy-gravity-index-production', prefix: 'builds/ArtistSimilarity/' },
    artist_trending: { bucket: 'artsy-gravity-index-production', prefix: 'builds/ArtistTrending/' },
    artwork_gene_value: { bucket: 'artsy-gravity-index-production', prefix: 'builds/ArtworkGeneValue/' },
    artwork_iconicity: { bucket: 'artsy-gravity-index-production', prefix: 'builds/ArtworkIconicity/' },
    artwork_merchandisability: { bucket: 'artsy-gravity-index-production', prefix: 'builds/ArtworkMerchandisability/' },
    cf_artwork_similarity: { bucket: 'artsy-gravity-index-production', prefix: 'builds/CFArtworkSimilarity/' },
    contemporary_artist_similarity: { bucket: 'artsy-gravity-index-production',
                                      prefix: 'builds/ContemporaryArtistSimilarity/' },
    gene_partitioned_artist_trending: { bucket: 'artsy-gravity-index-production',
                                        prefix: 'builds/GenePartitionedArtistTrending/' },
    gene_similarity: { bucket: 'artsy-gravity-index-production', prefix: 'builds/GeneSimilarity/' },
    homefeed_artist_reco: { bucket: 'artsy-data-platform-production', prefix: 'artist_recommendations/' },
    homefeed_artwork_reco: { bucket: 'artsy-data-platform-production', prefix: 'artwork_recommendations/' },
    sitemaps: { bucket: 'artsy-sitemaps', prefix: 'sitemap-artist-series' }, # This is because in hue artist series is the last task to run in the chained sitemap tasks
    tag_count: { bucket: 'artsy-gravity-index-production', prefix: 'builds/TagCount/' },
    user_artwork_suggestions: { bucket: 'artsy-gravity-index-production', prefix: 'builds/UserArtworkSuggestions/' },
    user_genome: { bucket: 'artsy-gravity-index-production', prefix: 'builds/UserGenome/' },
    user_price_preference: { bucket: 'artsy-gravity-index-production', prefix: 'builds/UserPricePreference/' },
    candela_email_batches: { bucket: 'artsy-data-platform-production', prefix: 'extracts/candela.email_batches/' },
    candela_emails: { bucket: 'artsy-data-platform-production', prefix: 'extracts/candela.emails/' },
    causality_calculated_events: { bucket: 'artsy-data-platform-production', prefix: 'extracts/causality.calculated_events/' },
    causality_events: { bucket: 'artsy-data-platform-production', prefix: 'extracts/causality.events/' },
    causality_lot_states: { bucket: 'artsy-data-platform-production', prefix: 'extracts/causality.lot_states/' },
    convection_assets: { bucket: 'artsy-data-platform-production', prefix: 'extracts/convection.assets/' },
    convection_notes: { bucket: 'artsy-data-platform-production', prefix: 'extracts/convection.notes/' },
    convection_offers: { bucket: 'artsy-data-platform-production', prefix: 'extracts/convection.offers/' },
    convection_partners: { bucket: 'artsy-data-platform-production', prefix: 'extracts/convection.partners/' },
    convection_partner_submissions: { bucket: 'artsy-data-platform-production', prefix: 'extracts/convection.partner_submissions/' },
    convection_submissions: { bucket: 'artsy-data-platform-production', prefix: 'extracts/convection.submissions/' },
    convection_users: { bucket: 'artsy-data-platform-production', prefix: 'extracts/convection.users/' },
    diffusion_lots: { bucket: 'artsy-data-platform-production', prefix: 'extracts/diffusion.lots/' },
    diffusion_source_lots: { bucket: 'artsy-data-platform-production', prefix: 'extracts/diffusion.source_lots/' },
    exchange_admin_notes: { bucket: 'artsy-data-platform-production', prefix: 'extracts/exchange.admin_notes/' },
    exchange_fraud_reviews: { bucket: 'artsy-data-platform-production', prefix: 'extracts/exchange.fraud_reviews/' },
    exchange_fulfillments: { bucket: 'artsy-data-platform-production', prefix: 'extracts/exchange.fulfillments/' },
    exchange_line_item_fulfillments: { bucket: 'artsy-data-platform-production', prefix: 'extracts/exchange.line_item_fulfillments/' },
    exchange_line_items: { bucket: 'artsy-data-platform-production', prefix: 'extracts/exchange.line_items/' },
    exchange_offers: { bucket: 'artsy-data-platform-production', prefix: 'extracts/exchange.offers/' },
    exchange_orders: { bucket: 'artsy-data-platform-production', prefix: 'extracts/exchange.orders/' },
    exchange_shipments: { bucket: 'artsy-data-platform-production', prefix: 'extracts/exchange.shipments/' },
    exchange_shipping_quote_requests: { bucket: 'artsy-data-platform-production', prefix: 'extracts/exchange.shipping_quote_requests/' },
    exchange_shipping_quotes: { bucket: 'artsy-data-platform-production', prefix: 'extracts/exchange.shipping_quotes/' },
    exchange_state_histories: { bucket: 'artsy-data-platform-production', prefix: 'extracts/exchange.state_histories/' },
    exchange_transactions: { bucket: 'artsy-data-platform-production', prefix: 'extracts/exchange.transactions/' },
    gravity_account_activities: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.account_activities/' },
    gravity_account_requests: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.account_requests/' },
    gravity_artists: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.artists/' },
    gravity_artist_series_artworks: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.artist_series_artworks/' },
    gravity_artwork_versions: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.artwork_versions/' },
    gravity_artworks: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.artworks/' },
    gravity_bidders: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.bidders/' },
    gravity_blocked_emails: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.blocked_emails/' },
    gravity_credit_cards: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.credit_cards/' },
    gravity_collected_artworks: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.collected_artworks/' },
    gravity_collector_profiles: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.collector_profiles/' },
    gravity_collections: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.collections/' },
    gravity_commission_exemptions: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.commission_exemptions/' },
    gravity_edition_sets: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.edition_sets/' },
    gravity_fair_organizers: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.fair_organizers/' },
    gravity_fairs: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.fairs/' },
    gravity_follow_artists: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.follow_artists/' },
    gravity_identity_verifications: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.identity_verifications/' },
    gravity_inquiry_requests: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.inquiry_requests/' },
    gravity_jumio_scan_references: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.jumio_scan_references/' },
    gravity_lot_events: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.lot_events' },
    gravity_lots: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.lots/' },
    gravity_merchant_accounts: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.merchant_accounts/' },
    gravity_offer_actions: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.offer_actions/' },
    gravity_offer_emails: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.offer_emails/' },
    gravity_partner_artists: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.partner_artists/' },
    gravity_partner_locations: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.partner_locations/' },
    gravity_partners: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.partners/' },
    gravity_partner_show_artworks: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.partner_show_artworks/' },
    gravity_partner_shows: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.partner_shows/' },
    gravity_partner_subscription_charges: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.partner_subscription_charges/' },
    gravity_partner_subscription_charge_line_items: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.partner_subscription_charge_line_items/' },
    gravity_partner_subscriptions: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.partner_subscriptions/' },
    gravity_profiles: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.profiles/' },
    gravity_purchases: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.purchases/' },
    gravity_representatives: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.representatives/' },
    gravity_resource_notes: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.resource_notes/' },
    gravity_sales: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.sales/' },
    gravity_sale_artworks: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.sale_artworks/' },
    gravity_search_criteria: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.search_criteria/' },
    gravity_second_factors: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.second_factors/' },
    gravity_user_interests: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.user_interests/' },
    gravity_users: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.users/' },
    gravity_user_search_criteria: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.user_search_criteria/' },
    gravity_viewing_room_artworks: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.viewing_room_artworks/' },
    gravity_viewing_rooms: { bucket: 'artsy-data-platform-production', prefix: 'extracts/gravity.viewing_rooms/' },
    impulse_assessments: { bucket: 'artsy-data-platform-production', prefix: 'extracts/impulse.assessments/' },
    impulse_attachments: { bucket: 'artsy-data-platform-production', prefix: 'extracts/impulse.attachments/' },
    impulse_conversations: { bucket: 'artsy-data-platform-production', prefix: 'extracts/impulse.conversations/' },
    impulse_conversation_items: { bucket: 'artsy-data-platform-production', prefix: 'extracts/impulse.conversation_items/' },
    impulse_deliveries: { bucket: 'artsy-data-platform-production', prefix: 'extracts/impulse.deliveries/' },
    impulse_email_addresses: { bucket: 'artsy-data-platform-production', prefix: 'extracts/impulse.email_addresses/' },
    impulse_email_address_conversations: { bucket: 'artsy-data-platform-production', prefix: 'extracts/impulse.email_address_conversations/' },
    impulse_email_conversations: { bucket: 'artsy-data-platform-production', prefix: 'extracts/impulse.email_conversations/' },
    impulse_email_messages: { bucket: 'artsy-data-platform-production', prefix: 'extracts/impulse.email_messages/' },
    impulse_events: { bucket: 'artsy-data-platform-production', prefix: 'extracts/impulse.events/' },
    impulse_messages: { bucket: 'artsy-data-platform-production', prefix: 'extracts/impulse.messages/' },
    impulse_reviews: { bucket: 'artsy-data-platform-production', prefix: 'extracts/impulse.reviews/' },
    positron_articles: { bucket: 'artsy-data-platform-production', prefix: 'extracts/positron.articles/' },
    marketo_clicks_email_link: { bucket: 'artsy-data-platform-production', prefix: 'extracts/marketo.clicks_email_link/' },
    marketo_email_bounces: { bucket: 'artsy-data-platform-production', prefix: 'extracts/marketo.email_bounces/' },
    marketo_email_delivers: { bucket: 'artsy-data-platform-production', prefix: 'extracts/marketo.email_delivers/' },
    marketo_email_opens: { bucket: 'artsy-data-platform-production', prefix: 'extracts/marketo.email_opens/' },
    marketo_email_sends: { bucket: 'artsy-data-platform-production', prefix: 'extracts/marketo.email_sends/' },
    marketo_email_unsubscribes: { bucket: 'artsy-data-platform-production', prefix: 'extracts/marketo.email_unsubscribes/' },
    marketo_fill_out_facebook_lead_ads_form: { bucket: 'artsy-data-platform-production', prefix: 'extracts/marketo.fill_out_facebook_lead_ads_form/' },
    marketo_form_submissions: { bucket: 'artsy-data-platform-production', prefix: 'extracts/marketo.form_submissions/' },
    marketo_forms: { bucket: 'artsy-data-platform-production', prefix: 'extracts/marketo.forms/' },
    marketo_activity_types: { bucket: 'artsy-data-platform-production', prefix: 'extracts/marketo.activity_types/' }
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
