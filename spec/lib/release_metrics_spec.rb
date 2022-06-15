# frozen_string_literal: true

require_relative '../../lib/release_metrics'

describe ReleaseMetrics do
  let(:github_client) { double(Octokit::Client) }
  let(:response) { double('Sawyer::Resource') }
  let(:issue) { double('Issue', node_id: 'foo') }

  before do
    allow(Octokit::Client).to receive(:new).and_return(github_client)
    allow(github_client).to receive(:post).and_return(response)
  end

  it 'tolerates nil errors' do
    allow(response).to receive_messages(
      errors: nil,
      data: double(node: double(commits: double(edges: [])))
    )
    expect(ReleaseMetrics.new.pull_requests_for_release(issue)).to eq([])
  end
end
