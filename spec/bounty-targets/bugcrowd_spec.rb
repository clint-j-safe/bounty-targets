# frozen_string_literal: true

require 'json'

describe BountyTargets::Bugcrowd do
  subject(:client) { described_class.new }

  before :all do
    described_class.make_all_methods_public!
  end

  let(:engagements_page_one) do
    {'engagements' => [{'briefUrl' => '/engagements/acme'}]}.to_json
  end

  let(:engagements_page_two) do
    {'engagements' => []}.to_json
  end

  let(:brief_html) do
    <<~HTML
      <html><body>
        <div data-react-class="ResearcherEngagementBrief"
          data-api-endpoints='{"engagementBriefApi":{"getBriefVersionDocument":"/engagements/acme/changelog/abc"}}'></div>
      </body></html>
    HTML
  end

  let(:brief) do
    {
      'coordinatedDisclosure' => false,
      'participation' => 'open',
      'publishedAt' => '2026-09-11T15:03:27.462Z',
      'lastTransitionAt' => '2017-04-13T19:00:00.000Z',
      'statusLabel' => 'In progress',
      'rewardAllocation' => 'pay_for_success',
      'data' => {
        'brief' => {
          'name' => 'Acme',
          'safeHarborStatus' => {'status' => 'complete'}
        },
        'engagement' => {
          'id' => '1e0e0003-4cb7-4563-a7f1-286302de8b25',
          'state' => 'in_progress',
          'startsAt' => '2017-04-13T19:00:00Z',
          'endsAt' => nil
        },
        'scope' => [
          {
            'inScope' => true,
            'rewardRangeData' => {'1' => {'min' => 2000, 'max' => 3000}, 'programMax' => 5000},
            'targets' => [
              {'category' => 'website', 'name' => 'acme.com', 'uri' => 'https://acme.com', 'ipAddress' => ''}
            ]
          },
          {
            'inScope' => false,
            'rewardRangeData' => {},
            'targets' => [
              {'category' => 'website', 'name' => 'out.acme.com', 'uri' => nil, 'ipAddress' => nil}
            ]
          }
        ]
      }
    }
  end

  it 'fetches a paginated list of programs' do
    stub_request(:get, %r{/engagements\.json}).with(headers: {host: 'bugcrowd.com'}).to_return(
      {status: 200, body: engagements_page_one},
      {status: 200, body: engagements_page_two}
    )

    expect(client.directory_index).to eq(['https://bugcrowd.com/engagements/acme'])
  end

  it 'fetches program details with enrichment fields' do
    stub_request(:get, %r{/engagements/acme$}).with(headers: {host: 'bugcrowd.com'})
      .to_return(status: 200, body: brief_html)
    stub_request(:get, %r{/engagements/acme/changelog/abc\.json}).with(headers: {host: 'bugcrowd.com'})
      .to_return(status: 200, body: brief.to_json)

    expect(client.parse_program('https://bugcrowd.com/engagements/acme')).to eq(
      {
        name: 'Acme',
        url: 'https://bugcrowd.com/engagements/acme',
        allows_disclosure: true,
        managed_by_bugcrowd: true,
        safe_harbor: 'complete',
        max_payout: 3000,
        starts_at: '2017-04-13T19:00:00Z',
        ends_at: nil,
        engagement_id: '1e0e0003-4cb7-4563-a7f1-286302de8b25',
        engagement_state: 'in_progress',
        participation: 'open',
        published_at: '2026-09-11T15:03:27.462Z',
        last_transition_at: '2017-04-13T19:00:00.000Z',
        status_label: 'In progress',
        reward_allocation: 'pay_for_success',
        targets: {
          in_scope: [
            {
              type: 'website',
              target: 'https://acme.com',
              uri: 'https://acme.com',
              name: 'acme.com',
              ipAddress: '',
              bounty: true
            }
          ],
          out_of_scope: [
            {
              type: 'website',
              target: 'out.acme.com',
              uri: nil,
              name: 'out.acme.com',
              ipAddress: nil,
              bounty: false
            }
          ]
        }
      }
    )
  end
end
