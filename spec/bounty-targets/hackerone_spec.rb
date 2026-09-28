# frozen_string_literal: true

require 'base64'
require 'json'

describe BountyTargets::Hackerone do
  subject(:client) { described_class.new }

  let(:directory_response) do
    {
      'data' => {
        'teams' => {
          'pageInfo' => {'endCursor' => nil, 'hasNextPage' => false},
          'nodes' => [
            {
              'allows_bounty_splitting' => true,
              'average_bounty_lower_amount' => 200,
              'average_bounty_upper_amount' => 300,
              'bounties_total' => '1234.56',
              'churned_at' => nil,
              'created_at' => '2016-01-02T03:04:05.000Z',
              'handle' => 'acme',
              'id' => Base64.strict_encode64('gid://hackerone/Engagements::Legacy/12345'),
              'last_report_resolved_at' => '2026-02-02T03:04:05.000Z',
              'last_updated_at' => '2026-01-02T03:04:05.000Z',
              'launched_at' => '2016-01-02T03:04:05.000Z',
              'minimum_bounty' => 100,
              'most_recent_sla_snapshot' => {
                'average_time_to_bounty_awarded' => 11,
                'average_time_to_first_program_response' => 22,
                'average_time_to_report_resolved' => 33
              },
              'name' => 'Acme',
              'offers_bounties' => true,
              'offers_swag' => false,
              'resolved_report_count' => 42,
              'response_efficiency_percentage' => 90,
              'started_accepting_at' => '2016-01-02T03:04:05.000Z',
              'state' => 'public_mode',
              'submission_state' => 'open',
              'triage_active' => true,
              'url' => 'https://hackerone.com/acme',
              'website' => 'https://acme.com'
            }
          ]
        }
      }
    }
  end

  let(:program_response) do
    {
      'data' => {
        'team' => {
          'structured_scopes' => {
            'pageInfo' => {'endCursor' => nil, 'hasNextPage' => false},
            'nodes' => [
              {
                'asset_identifier' => '*.acme.com',
                'asset_type' => 'WILDCARD',
                'created_at' => '2020-01-01T00:00:00.000Z',
                'eligible_for_bounty' => true,
                'eligible_for_submission' => true,
                'instruction' => 'In scope',
                'max_severity' => 'critical',
                'updated_at' => '2026-01-01T00:00:00.000Z'
              },
              {
                'asset_identifier' => 'https://nil.acme.com',
                'asset_type' => 'URL',
                'eligible_for_bounty' => nil,
                'eligible_for_submission' => nil
              },
              {
                'asset_identifier' => 'https://out.acme.com',
                'asset_type' => 'URL',
                'eligible_for_bounty' => false,
                'eligible_for_submission' => false
              }
            ]
          }
        }
      }
    }
  end

  before do
    stub_request(:get, 'https://hackerone.com/directory/programs').to_return(
      status: 200,
      headers: {'Set-Cookie' => 'session=abc'},
      body: '<html><head><meta name="csrf-token" content="test-csrf-token"></head></html>'
    )
    stub_request(:post, 'https://hackerone.com/graphql').to_return do |request|
      response = JSON.parse(request.body)['query'].include?('teams(') ? directory_response : program_response
      {status: 200, headers: {'Content-Type' => 'application/json'}, body: response.to_json}
    end
  end

  it 'fetches a list of programs with enrichment fields' do
    expect(client.directory_index).to eq(
      [
        {
          allows_bounty_splitting: true,
          average_bounty_lower_amount: 200,
          average_bounty_upper_amount: 300,
          average_time_to_bounty_awarded: 11,
          average_time_to_first_program_response: 22,
          average_time_to_report_resolved: 33,
          bounties_total: '1234.56',
          churned_at: nil,
          created_at: '2016-01-02T03:04:05.000Z',
          handle: 'acme',
          id: 12_345,
          last_report_resolved_at: '2026-02-02T03:04:05.000Z',
          last_updated_at: '2026-01-02T03:04:05.000Z',
          launched_at: '2016-01-02T03:04:05.000Z',
          managed_program: true,
          minimum_bounty: 100,
          name: 'Acme',
          offers_bounties: true,
          offers_swag: false,
          resolved_report_count: 42,
          response_efficiency_percentage: 90,
          started_accepting_at: '2016-01-02T03:04:05.000Z',
          state: 'public_mode',
          submission_state: 'open',
          url: 'https://hackerone.com/acme',
          website: 'https://acme.com'
        }
      ]
    )
  end

  it 'requests the enrichment fields in the directory query' do
    expect(client.instance_variable_get(:@directory_query)).to include(
      'started_accepting_at',
      'last_updated_at',
      'launched_at',
      'created_at',
      'churned_at',
      'last_report_resolved_at',
      'bounties_total',
      'resolved_report_count',
      'minimum_bounty',
      'average_bounty_lower_amount',
      'average_bounty_upper_amount',
      'state'
    )
  end

  it 'fetches program targets with scope enrichment fields' do
    expect(client.program_targets(handle: 'acme')).to eq(
      [
        [
          {
            'asset_identifier' => '*.acme.com',
            'asset_type' => 'WILDCARD',
            'created_at' => '2020-01-01T00:00:00.000Z',
            'eligible_for_bounty' => true,
            'eligible_for_submission' => true,
            'instruction' => 'In scope',
            'max_severity' => 'critical',
            'updated_at' => '2026-01-01T00:00:00.000Z'
          },
          {
            'asset_identifier' => 'https://nil.acme.com',
            'asset_type' => 'URL',
            'eligible_for_bounty' => nil,
            'eligible_for_submission' => nil
          }
        ],
        [
          {
            'asset_identifier' => 'https://out.acme.com',
            'asset_type' => 'URL',
            'eligible_for_bounty' => false,
            'eligible_for_submission' => false
          }
        ]
      ]
    )
  end

  it 'requests the enrichment fields in the program query' do
    expect(client.instance_variable_get(:@program_query)).to include('created_at', 'updated_at')
  end
end
