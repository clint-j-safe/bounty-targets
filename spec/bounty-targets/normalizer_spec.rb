# frozen_string_literal: true

require 'json'
require 'time'
require 'tmpdir'

describe BountyTargets::Normalizer do
  def hackerone_program(overrides = {})
    {
      'allows_bounty_splitting' => true,
      'average_bounty_lower_amount' => 200,
      'average_bounty_upper_amount' => 300,
      'average_time_to_bounty_awarded' => 11,
      'average_time_to_first_program_response' => 22,
      'average_time_to_report_resolved' => 33,
      'bounties_total' => '1234.56',
      'churned_at' => nil,
      'created_at' => '2016-01-02T03:04:05.000Z',
      'handle' => 'acme',
      'id' => 12_345,
      'last_report_resolved_at' => '2026-02-02T03:04:05.000Z',
      'last_updated_at' => '2026-01-02T03:04:05.000Z',
      'launched_at' => '2016-01-02T03:04:05.000Z',
      'managed_program' => true,
      'minimum_bounty' => 100,
      'name' => 'Acme',
      'offers_bounties' => true,
      'offers_swag' => false,
      'resolved_report_count' => 42,
      'response_efficiency_percentage' => 90,
      'started_accepting_at' => '2016-01-02T03:04:05.000Z',
      'state' => 'public_mode',
      'submission_state' => 'open',
      'url' => 'https://hackerone.com/acme',
      'website' => 'https://acme.com',
      'targets' => {
        'in_scope' => [
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
            'eligible_for_submission' => true
          }
        ],
        'out_of_scope' => [
          {
            'asset_identifier' => 'https://out.acme.com',
            'asset_type' => 'URL',
            'eligible_for_bounty' => false,
            'eligible_for_submission' => false
          }
        ]
      }
    }.merge(overrides)
  end

  def bugcrowd_program(overrides = {})
    {
      'allows_disclosure' => true,
      'ends_at' => nil,
      'engagement_id' => '1e0e0003-4cb7-4563-a7f1-286302de8b25',
      'engagement_state' => 'in_progress',
      'last_transition_at' => '2017-04-13T19:00:00.000Z',
      'managed_by_bugcrowd' => true,
      'max_payout' => 3000,
      'name' => 'Acme',
      'participation' => 'open',
      'published_at' => '2026-09-11T15:03:27.462Z',
      'reward_allocation' => 'pay_for_success',
      'safe_harbor' => 'complete',
      'starts_at' => '2017-04-13T19:00:00Z',
      'status_label' => 'In progress',
      'url' => 'https://bugcrowd.com/engagements/acme',
      'targets' => {
        'in_scope' => [
          {
            'bounty' => true,
            'ipAddress' => '',
            'name' => 'acme.com',
            'target' => 'https://acme.com',
            'type' => 'website',
            'uri' => 'https://acme.com'
          }
        ],
        'out_of_scope' => [
          {
            'bounty' => false,
            'ipAddress' => nil,
            'name' => 'out.acme.com',
            'target' => 'out.acme.com',
            'type' => 'website',
            'uri' => nil
          }
        ]
      }
    }.merge(overrides)
  end
  def intigriti_program(overrides = {})
    {
      'accepted_submission_count' => 2,
      'average_payout' => 123,
      'company_handle' => 'intel',
      'handle' => 'intel',
      'has_updates' => true,
      'id' => 'intel-id',
      'last_activity_at' => 1_775_335_590,
      'last_submission_at' => 1_790_548_344,
      'last_updated_at' => 1_789_969_353,
      'created_at' => 1_789_634_437,
      'max_bounty' => {'currency' => 'EUR', 'value' => 5000},
      'min_bounty' => {'currency' => 'EUR', 'value' => 50},
      'name' => 'Intel',
      'program_type' => 'Bug bounty',
      'status' => 'open',
      'submission_count' => 10,
      'total_payout' => 678.9,
      'url' => 'https://www.intigriti.com/programs/intel/intel/detail',
      'targets' => {
        'in_scope' => [
          {'description' => nil, 'endpoint' => 'app.intigriti.com', 'impact' => 'Tier 1', 'type' => 'url'},
          {'description' => 'docs', 'endpoint' => 'docs.intigriti.com', 'impact' => 'No Bounty', 'type' => 'url'}
        ],
        'out_of_scope' => [
          {'description' => 'nope', 'endpoint' => 'out.intigriti.com', 'impact' => 'Out of scope', 'type' => 'url'}
        ]
      }
    }.merge(overrides)
  end

  def yeswehack_program(overrides = {})
    {
      'archived' => false,
      'bounty' => true,
      'disabled' => false,
      'event' => nil,
      'gift' => false,
      'id' => 'stopcovid',
      'last_update_at' => '2026-09-24T17:12:59+02:00',
      'managed' => false,
      'max_bounty' => 2000,
      'min_bounty' => 0,
      'name' => 'StopCovid',
      'public' => true,
      'reports_count' => 109,
      'scopes_count' => 2,
      'stats' => {'total_reports' => 109},
      'status' => 'V',
      'url' => 'https://yeswehack.com/programs/stopcovid',
      'vdp' => false,
      'targets' => {
        'in_scope' => [
          {'asset_value' => 'HIGH', 'report_count' => 12, 'target' => 'api.stopcovid.gouv.fr', 'type' => 'api'}
        ],
        'out_of_scope' => [
          {'target' => 'Everything that is not part of the scope', 'type' => 'other'}
        ]
      }
    }.merge(overrides)
  end

  def federacy_program(overrides = {})
    {
      'award_critical' => 1500,
      'award_high' => 900,
      'award_low' => 100,
      'award_medium' => 300,
      'created_at' => '2018-07-27T02:29:36.516Z',
      'id' => '955a3f33-3ca7-42b1-acf5-84da28d4c08c',
      'managed' => false,
      'name' => 'Federacy',
      'offers_awards' => true,
      'public' => true,
      'url' => 'https://www.federacy.com/federacy',
      'targets' => {
        'in_scope' => [
          {
            'bounty' => 'money',
            'identifier_type' => nil,
            'impact' => 'high',
            'target' => 'www.federacy.com',
            'type' => 'website'
          }
        ],
        'out_of_scope' => []
      }
    }.merge(overrides)
  end

  describe '.normalize' do
    it 'normalizes a hackerone program' do
      expect(described_class.normalize('hackerone', [hackerone_program])).to eq(
        [
          {
            'platform' => 'hackerone',
            'id' => 12_345,
            'handle' => 'acme',
            'name' => 'Acme',
            'url' => 'https://hackerone.com/acme',
            'offers_bounty' => true,
            'submission_state' => 'open',
            'managed' => true,
            'first_started_at' => '2016-01-02T03:04:05Z',
            'last_updated_at' => '2026-01-02T03:04:05Z',
            'last_activity_at' => '2026-02-02T03:04:05Z',
            'reports_count' => nil,
            'resolved_reports_count' => 42,
            'total_bounty_amount' => 1234.56,
            'bounty_min' => 100,
            'bounty_max' => nil,
            'targets' => [
              {
                'type' => 'WILDCARD',
                'target' => '*.acme.com',
                'in_scope' => true,
                'bounty' => true,
                'updated_at' => '2026-01-01T00:00:00Z',
                'severity' => 'critical',
                'instruction' => 'In scope'
              },
              {
                'type' => 'URL',
                'target' => 'https://nil.acme.com',
                'in_scope' => true,
                'bounty' => nil,
                'updated_at' => nil,
                'severity' => nil,
                'instruction' => nil
              },
              {
                'type' => 'URL',
                'target' => 'https://out.acme.com',
                'in_scope' => false,
                'bounty' => false,
                'updated_at' => nil,
                'severity' => nil,
                'instruction' => nil
              }
            ]
          }
        ]
      )
    end

    it 'normalizes a bugcrowd program' do
      expect(described_class.normalize('bugcrowd', [bugcrowd_program])).to eq(
        [
          {
            'platform' => 'bugcrowd',
            'id' => '1e0e0003-4cb7-4563-a7f1-286302de8b25',
            'handle' => nil,
            'name' => 'Acme',
            'url' => 'https://bugcrowd.com/engagements/acme',
            'offers_bounty' => true,
            'submission_state' => 'in_progress',
            'managed' => true,
            'first_started_at' => '2017-04-13T19:00:00Z',
            'last_updated_at' => '2026-09-11T15:03:27Z',
            'last_activity_at' => '2017-04-13T19:00:00Z',
            'reports_count' => nil,
            'resolved_reports_count' => nil,
            'total_bounty_amount' => nil,
            'bounty_min' => nil,
            'bounty_max' => 3000,
            'targets' => [
              {
                'type' => 'website',
                'target' => 'https://acme.com',
                'in_scope' => true,
                'bounty' => true,
                'updated_at' => nil,
                'severity' => nil,
                'instruction' => nil
              },
              {
                'type' => 'website',
                'target' => 'out.acme.com',
                'in_scope' => false,
                'bounty' => false,
                'updated_at' => nil,
                'severity' => nil,
                'instruction' => nil
              }
            ]
          }
        ]
      )
    end

    it 'normalizes an intigriti program' do
      expect(described_class.normalize('intigriti', [intigriti_program])).to eq(
        [
          {
            'platform' => 'intigriti',
            'id' => 'intel-id',
            'handle' => 'intel',
            'name' => 'Intel',
            'url' => 'https://www.intigriti.com/programs/intel/intel/detail',
            'offers_bounty' => true,
            'submission_state' => 'open',
            'managed' => nil,
            'first_started_at' => '2026-09-17T08:40:37Z',
            'last_updated_at' => '2026-09-21T05:42:33Z',
            'last_activity_at' => '2026-09-27T22:32:24Z',
            'reports_count' => 10,
            'resolved_reports_count' => 2,
            'total_bounty_amount' => 678.9,
            'bounty_min' => 50,
            'bounty_max' => 5000,
            'targets' => [
              { 'type' => 'url', 'target' => 'app.intigriti.com', 'in_scope' => true, 'bounty' => true,
                'updated_at' => nil, 'severity' => 'Tier 1', 'instruction' => nil },
              { 'type' => 'url', 'target' => 'docs.intigriti.com', 'in_scope' => true, 'bounty' => false,
                'updated_at' => nil, 'severity' => 'No Bounty', 'instruction' => 'docs' },
              { 'type' => 'url', 'target' => 'out.intigriti.com', 'in_scope' => false, 'bounty' => false,
                'updated_at' => nil, 'severity' => nil, 'instruction' => 'nope' }
            ]
          }
        ]
      )
    end

    it 'normalizes a yeswehack program' do
      expect(described_class.normalize('yeswehack', [yeswehack_program])).to eq(
        [
          {
            'platform' => 'yeswehack',
            'id' => 'stopcovid',
            'handle' => nil,
            'name' => 'StopCovid',
            'url' => 'https://yeswehack.com/programs/stopcovid',
            'offers_bounty' => true,
            'submission_state' => nil,
            'managed' => false,
            'first_started_at' => nil,
            'last_updated_at' => '2026-09-24T15:12:59Z',
            'last_activity_at' => nil,
            'reports_count' => 109,
            'resolved_reports_count' => nil,
            'total_bounty_amount' => nil,
            'bounty_min' => 0,
            'bounty_max' => 2000,
            'targets' => [
              { 'type' => 'api', 'target' => 'api.stopcovid.gouv.fr', 'in_scope' => true, 'bounty' => nil,
                'updated_at' => nil, 'severity' => 'HIGH', 'instruction' => nil },
              { 'type' => 'other', 'target' => 'Everything that is not part of the scope', 'in_scope' => false,
                'bounty' => false, 'updated_at' => nil, 'severity' => nil, 'instruction' => nil }
            ]
          }
        ]
      )
    end

    it 'normalizes a federacy program' do
      expect(described_class.normalize('federacy', [federacy_program])).to eq(
        [
          {
            'platform' => 'federacy',
            'id' => '955a3f33-3ca7-42b1-acf5-84da28d4c08c',
            'handle' => nil,
            'name' => 'Federacy',
            'url' => 'https://www.federacy.com/federacy',
            'offers_bounty' => true,
            'submission_state' => nil,
            'managed' => false,
            'first_started_at' => '2018-07-27T02:29:36Z',
            'last_updated_at' => nil,
            'last_activity_at' => nil,
            'reports_count' => nil,
            'resolved_reports_count' => nil,
            'total_bounty_amount' => nil,
            'bounty_min' => 100,
            'bounty_max' => 1500,
            'targets' => [
              {
                'type' => 'website',
                'target' => 'www.federacy.com',
                'in_scope' => true,
                'bounty' => true,
                'updated_at' => nil,
                'severity' => 'high',
                'instruction' => nil
              }
            ]
          }
        ]
      )
    end
  end

  describe '.dump' do
    def payload
      result = nil
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'hackerone_data.json'),
          JSON.generate([hackerone_program('last_updated_at' => nil)]))
        File.write(File.join(dir, 'intigriti_data.json'), JSON.generate([intigriti_program]))
        File.write(File.join(dir, 'yeswehack_data.json'), JSON.generate([yeswehack_program]))
        described_class.dump(dir)
        result = JSON.parse(File.read(File.join(dir, 'programs.json')))
      end
      result
    end

    it 'writes programs from every platform that has a data file' do
      expect(payload['programs'].length).to eq(3)
    end

    it 'sorts programs by last update date descending and keeps missing dates last' do
      expect(payload['programs'].map { |program| program['id'] }).to eq(['stopcovid', 'intel-id', 12_345])
    end

    it 'stamps the file with the generation time' do
      expect(Time.iso8601(payload['generated_at'])).to be_within(60).of(Time.now)
    end
  end
end
