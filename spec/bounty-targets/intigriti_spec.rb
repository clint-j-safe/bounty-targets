# frozen_string_literal: true

describe BountyTargets::Intigriti do
  subject(:client) { described_class.new }

  before :all do
    described_class.make_all_methods_public!
  end

  it 'fetches a list of programs' do
    programs = File.read('spec/fixtures/intigriti/programs.json')
    stub_request(:post, %r{/1/indexes/\*/queries}).with(headers: {host: 'aazuksyar4-dsn.algolia.net'})
      .to_return(status: 200, body: programs)
    expect(client.directory_index).to eq(
      [
        {
          company_handle: 'buhlergroup',
          confidentiality_level: 'public',
          created_at: 1_789_634_437,
          handle: 'buhlergroupvdp',
          id: '4afd6f0f-40a3-4f6d-a332-56b5970d12a0',
          last_submission_at: 1_745_679_893,
          last_updated_at: 1_745_485_768,
          max_bounty: {'currency' => 'EUR', 'value' => 0},
          min_bounty: {'currency' => 'EUR', 'value' => 0},
          name: 'Bühler Group VDP',
          program_type: 'Responsible disclosure',
          status: 'open',
          tacRequired: false,
          twoFactorRequired: false,
          url: 'https://www.intigriti.com/programs/buhlergroup/buhlergroupvdp/detail'
        }
      ]
    )
  end

  it 'fetches program scopes' do
    scopes = File.read('spec/fixtures/intigriti/scopes.json')
    stub_request(:get, %r{/api/core/public/programs/intel/intel})
      .with(headers: {host: 'app.intigriti.com'}).to_return(status: 200, body: scopes)
    expect(client.program_scopes(company_handle: 'intel', handle: 'intel')).to eq(
      accepted_submission_count: 0,
      average_payout: nil,
      has_updates: true,
      last_activity_at: 1_775_335_590,
      submission_count: 0,
      targets: {
        in_scope: [
          {
            description: nil,
            endpoint: 'endpoint',
            impact: 'Tier 1',
            type: 'other'
          }
        ],
        out_of_scope: []
      },
      total_payout: nil
    )
  end
end
