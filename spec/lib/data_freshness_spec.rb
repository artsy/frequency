# frozen_string_literal: true

require_relative '../../lib/data_freshness'

describe DataFreshness do
  before do
    s_3_client = double("Aws::S3::Client")
    response = double('Response')
    allow(Aws::S3::Client).to receive(:new).and_return(s_3_client)
    allow(s_3_client).to receive(:list_objects).and_return([response])
    allow(response).to receive(:contents).and_return []
  end

  it 'records metrics' do
    expect(described_class.record_metrics).to eq DataFreshness::S3_LOCATIONS
  end
end
