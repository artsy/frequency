# frozen_string_literal: true

require_relative './aws_helper'
require 'datadog/statsd'

class SpotPrice
  def self.record_metrics()
    new.record_metrics
  end

  def record_metrics
    # instance types we allow in Spot instance groups.
    %w(c5.xlarge r5.xlarge m5.xlarge c6i.xlarge r6i.xlarge m6i.xlarge).each do |instance_type|
      price = get_spot_price(instance_type)
      statsd.gauge("spot_price", price, tags: ["spot_instance_type:#{instance_type}"])
      warn "Recorded price for #{instance_type} Spot instance: #{price} (0 means failure to obtain price)"
    end
  end

  def get_spot_price(instance_type)
    ec2client = AwsHelper.ec2_client
    resp = ec2client.describe_spot_price_history({
      start_time: Time.now.utc,
      instance_types: [instance_type], 
      product_descriptions: ["Linux/UNIX"], 
      availability_zone: "us-east-1b" # we also use zones 'c' and 'd', skipping them for now.
    })
    # resp should return 1 result telling us the last time spot price was changed and what the price was changed to, example:
    # {:availability_zone=>"us-east-1b", :instance_type=>"c5.xlarge", :product_description=>"Linux/UNIX", :spot_price=>"0.079900", :timestamp=>2022-10-18 18:28:15 UTC}
    if resp.dig(:spot_price_history, 0, :timestamp)
      return resp[:spot_price_history][0][:spot_price]
    else
      return 0.0
    end
  end

  def statsd
    @statsd ||= Datadog::Statsd.new(Config.values[:dd_agent_host])
  end
end
