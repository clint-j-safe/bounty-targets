# frozen_string_literal: true

describe BountyTargets::Federacy do
  subject(:client) { described_class.new }

  before :all do
    described_class.make_all_methods_public!
  end

  it 'fetches a list of programs' do
    programs = File.read('spec/fixtures/federacy/programs.json')
    stub_request(:get, %r{/api/public_programs}).with(headers: {host: 'www.federacy.com'})
      .to_return(status: 200, body: programs)
    expect(client.directory_index).to eq(
      [
        {
          award_critical: 1500,
          award_high: 900,
          award_low: 100,
          award_medium: 300,
          created_at: '2018-07-27T02:29:36.516Z',
          id: '955a3f33-3ca7-42b1-acf5-84da28d4c08c',
          managed: false,
          name: 'Federacy',
          offers_awards: true,
          public: true,
          url: 'https://www.federacy.com/federacy'
        },
        {
          award_critical: 0,
          award_high: 0,
          award_low: 0,
          award_medium: 0,
          created_at: '2018-08-07T02:51:12.348Z',
          id: '50cea250-a08a-4581-93a5-5d973a261f45',
          managed: false,
          name: 'CoinTracker',
          offers_awards: false,
          public: true,
          url: 'https://www.federacy.com/cointracker'
        }
      ]
    )
  end

  it 'fetches program scopes' do
    scopes = File.read('spec/fixtures/federacy/scopes.json')
    stub_request(:get, %r{/api/public_programs/50cea250-a08a-4581-93a5-5d973a261f45/program_scopes})
      .with(headers: {host: 'www.federacy.com'})
      .to_return(status: 200, body: scopes)
    expect(client.program_scopes(id: '50cea250-a08a-4581-93a5-5d973a261f45')).to eq(
      targets: {
        in_scope: [
          {
            bounty: 'money',
            identifier_type: nil,
            impact: 'high',
            type: 'website',
            target: 'www.cointracker.io'
          },
          {
            bounty: 'money',
            identifier_type: nil,
            impact: 'high',
            type: 'mobile app',
            target: 'https://itunes.apple.com/us/app/cointracker-crypto-portfolio/id1401499763?mt=8'
          },
          {
            bounty: 'money',
            identifier_type: nil,
            impact: 'high',
            type: 'mobile app',
            target: 'https://play.google.com/store/apps/details?id=io.cointracker.android'
          }
        ],
        out_of_scope: []
      }
    )
  end
end
