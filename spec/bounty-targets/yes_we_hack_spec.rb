# frozen_string_literal: true

describe BountyTargets::YesWeHack do
  subject(:client) { described_class.new }

  before :all do
    described_class.make_all_methods_public!
  end

  it 'fetches a list of programs' do
    programs = File.read('spec/fixtures/yes_we_hack/programs.json')
    stub_request(:get, %r{/programs}).with(headers: {host: 'api.yeswehack.com'})
      .to_return(status: 200, body: programs)
    expect(client.directory_index).to eq(
      [
        {
          archived: false,
          bounty: true,
          disabled: false,
          event: nil,
          gift: false,
          id: 'stopcovid-bugbounty-program',
          last_update_at: '2026-09-24T17:12:59+02:00',
          managed: false,
          max_bounty: 2000,
          min_bounty: 0,
          name: 'StopCovid France Bug Bounty program',
          public: true,
          reports_count: 26,
          scopes_count: 5,
          status: 'V',
          url: 'https://yeswehack.com/programs/stopcovid-bugbounty-program',
          vdp: false
        }
      ]
    )
  end

  it 'fetches program scopes' do
    scopes = File.read('spec/fixtures/yes_we_hack/scopes.json')
    stub_request(:get, %r{/programs/stopcovid-bugbounty-program})
      .with(headers: {host: 'api.yeswehack.com'}).to_return(status: 200, body: scopes)
    expect(client.program_scopes(id: 'stopcovid-bugbounty-program')).to eq(
      stats: {
        'average_first_time_response' => 1,
        'average_reward' => nil,
        'max_reward' => nil,
        'total_hunter_thanked' => 1,
        'total_reports' => 26,
        'total_reports_current_month' => 1,
        'total_reports_last24_hours' => 0,
        'total_reports_last7_days' => 1
      },
      targets: {
        in_scope: [
          {
            asset_value: 'HIGH',
            report_count: 12,
            target: 'https://play.google.com/store/apps/details?id=fr.gouv.android.stopcovid',
            type: 'mobile-application-android'
          },
          {
            asset_value: nil,
            report_count: nil,
            target: 'https://apps.apple.com/fr/app/stopcovid-france/id1511279125',
            type: 'mobile-application-ios'
          },
          {
            asset_value: 'MEDIUM',
            report_count: 0,
            target: 'api.stopcovid.gouv.fr',
            type: 'api'
          },
          {
            asset_value: nil,
            report_count: nil,
            target: 'app.stopcovid.gouv.fr',
            type: 'api'
          },
          {
            asset_value: nil,
            report_count: nil,
            target: 'bonjour.stopcovid.gouv.fr',
            type: 'api'
          }
        ],
        out_of_scope: [
          {
            target: 'Everything that is not part of the scope',
            type: 'other'
          }
        ]
      }
    )
  end
end
