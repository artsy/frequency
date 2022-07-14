# frozen_string_literal: true

require 'datadog/statsd'
require_relative './config'
require_relative './aws_helper'

# Records timeliness of extracts tasks' results on S3
class DataFreshness
  S3_LOCATIONS = {
    impulse_conversations: { bucket: 'artsy-data', prefix: 'reports/impulse_conversations/' },
    impulse_conversation_items: { bucket: 'artsy-data', prefix: 'reports/impulse_conversation_items/' },
    impulse_messages: { bucket: 'artsy-data', prefix: 'reports/impulse_messages/' },
    impulse_assessments: { bucket: 'artsy-data', prefix: 'reports/impulse_assessments/' },
    convection_assets: { bucket: 'artsy-data', prefix: 'reports/convection_assets/' },
    convection_offers: { bucket: 'artsy-data', prefix: 'reports/convection_offers/' },
    convection_partners: { bucket: 'artsy-data', prefix: 'reports/convection_partners/' },
    convection_partner_submissions: { bucket: 'artsy-data', prefix: 'reports/convection_partner_submissions/' },
    convection_submissions: { bucket: 'artsy-data', prefix: 'reports/convection_submissions/' },
    convection_users: { bucket: 'artsy-data', prefix: 'reports/convection_users/' },
    convection_notes: { bucket: 'artsy-data', prefix: 'reports/convection_notes/' },
    causality_high_bids: { bucket: 'artsy-data', prefix: 'reports/causality_high_bids/' },
    causality_calculated_events: { bucket: 'artsy-data', prefix: 'reports/causality_calculated_events/' },
    causality_events: { bucket: 'artsy-data', prefix: 'reports/causality_events/' },
    causality_lot_states: { bucket: 'artsy-data', prefix: 'reports/causality_lot_states/' },
    positron_articles: { bucket: 'artsy-data', prefix: 'reports/positron_articles/' },
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
    candela_email_batches: { bucket: 'artsy-data', prefix: 'reports/candela_email_batches/' },
    candela_emails: { bucket: 'artsy-data', prefix: 'reports/candela_emails/' },
    marketo_activity_types: { bucket: 'artsy-data', prefix: 'reports/marketo_activity_types/' },
    marketo_form_submissions: { bucket: 'artsy-data', prefix: 'reports/marketo_form_submissions/' },
    diffusion_lots_archive: { bucket: 'artsy-data', prefix: 'reports/diffusion_lots_archive/' },
    diffusion_lots: { bucket: 'artsy-data', prefix: 'reports/diffusion_lots/' },
    diffusion_source_lots_archive: { bucket: 'artsy-data', prefix: 'reports/diffusion_source_lots_archive/' },
    diffusion_source_lots: { bucket: 'artsy-data', prefix: 'reports/diffusion_source_lots/' },

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
      statsd.gauge "gravity_extract_freshness.#{key}", age # seconds
    end
  end

  def statsd
    @statsd ||= Datadog::Statsd.new(Config.values[:dd_agent_host])
  end
end
