# frozen_string_literal: true

require 'json'
require 'time'

module BountyTargets
  class Normalizer
    PLATFORMS = %w[bugcrowd federacy hackerone intigriti yeswehack].freeze

    class << self
      def normalize(platform, programs)
        programs.map do |program|
          new.send(:"normalize_#{platform}", program)
        end
      end

      def dump(output_dir)
        programs = PLATFORMS.flat_map do |platform|
          path = File.join(output_dir, "#{platform}_data.json")
          next [] unless File.exist?(path)

          normalize(platform, ::JSON.parse(File.read(path)))
        end

        payload = {
          'generated_at' => Time.now.utc.iso8601,
          'programs' => programs.sort_by { |program| program['last_updated_at'].to_s }.reverse
        }
        File.write(File.join(output_dir, 'programs.json'), ::JSON.pretty_generate(payload))
      end
    end

    private

    def normalize_hackerone(program)
      in_scope = program.dig('targets', 'in_scope').to_a.map do |scope|
        target(
          type: scope['asset_type'],
          target: scope['asset_identifier'],
          in_scope: true,
          bounty: program['offers_bounties'] && scope['eligible_for_bounty'],
          updated_at: scope['updated_at'],
          severity: scope['max_severity'],
          instruction: scope['instruction']
        )
      end
      out_of_scope = program.dig('targets', 'out_of_scope').to_a.map do |scope|
        target(
          type: scope['asset_type'],
          target: scope['asset_identifier'],
          in_scope: false,
          bounty: false,
          updated_at: scope['updated_at'],
          severity: scope['max_severity'],
          instruction: scope['instruction']
        )
      end

      program_hash(
        platform: 'hackerone',
        id: program['id'],
        handle: program['handle'],
        name: program['name'],
        url: program['url'],
        offers_bounty: program['offers_bounties'],
        submission_state: program['submission_state'],
        managed: program['managed_program'],
        first_started_at: program['started_accepting_at'],
        last_updated_at: program['last_updated_at'],
        last_activity_at: program['last_report_resolved_at'],
        reports_count: nil,
        resolved_reports_count: program['resolved_report_count'],
        total_bounty_amount: to_float(program['bounties_total']),
        bounty_min: program['minimum_bounty'],
        bounty_max: nil,
        targets: in_scope + out_of_scope
      )
    end

    def normalize_bugcrowd(program)
      in_scope = program.dig('targets', 'in_scope').to_a.map do |scope|
        target(
          type: scope['type'],
          target: scope['target'],
          in_scope: true,
          bounty: scope['bounty'],
          updated_at: nil,
          severity: nil,
          instruction: nil
        )
      end
      out_of_scope = program.dig('targets', 'out_of_scope').to_a.map do |scope|
        target(
          type: scope['type'],
          target: scope['target'],
          in_scope: false,
          bounty: false,
          updated_at: nil,
          severity: nil,
          instruction: nil
        )
      end

      program_hash(
        platform: 'bugcrowd',
        id: program['engagement_id'],
        handle: nil,
        name: program['name'],
        url: program['url'],
        offers_bounty: in_scope.any? { |scope| scope['bounty'] == true },
        submission_state: program['engagement_state'],
        managed: program['managed_by_bugcrowd'],
        first_started_at: program['starts_at'],
        last_updated_at: program['published_at'],
        last_activity_at: program['last_transition_at'],
        reports_count: nil,
        resolved_reports_count: nil,
        total_bounty_amount: nil,
        bounty_min: nil,
        bounty_max: program['max_payout'],
        targets: in_scope + out_of_scope
      )
    end

    def normalize_intigriti(program)
      in_scope = program.dig('targets', 'in_scope').to_a.map do |scope|
        target(
          type: scope['type'],
          target: scope['endpoint'],
          in_scope: true,
          bounty: bounty_tier?(scope['impact']),
          updated_at: nil,
          severity: scope['impact'],
          instruction: scope['description']
        )
      end
      out_of_scope = program.dig('targets', 'out_of_scope').to_a.map do |scope|
        target(
          type: scope['type'],
          target: scope['endpoint'],
          in_scope: false,
          bounty: false,
          updated_at: nil,
          severity: nil,
          instruction: scope['description']
        )
      end

      program_hash(
        platform: 'intigriti',
        id: program['id'],
        handle: program['handle'],
        name: program['name'],
        url: program['url'],
        offers_bounty: intigriti_offers_bounty?(program, in_scope),
        submission_state: program['status'],
        managed: nil,
        first_started_at: program['created_at'],
        last_updated_at: program['last_updated_at'],
        last_activity_at: program['last_submission_at'] || program['last_activity_at'],
        reports_count: program['submission_count'],
        resolved_reports_count: program['accepted_submission_count'],
        total_bounty_amount: program['total_payout'],
        bounty_min: money_value(program['min_bounty']),
        bounty_max: money_value(program['max_bounty']),
        targets: in_scope + out_of_scope
      )
    end

    def normalize_yeswehack(program)
      in_scope = program.dig('targets', 'in_scope').to_a.map do |scope|
        target(
          type: scope['type'],
          target: scope['target'],
          in_scope: true,
          bounty: nil,
          updated_at: nil,
          severity: scope['asset_value'],
          instruction: nil
        )
      end
      out_of_scope = program.dig('targets', 'out_of_scope').to_a.map do |scope|
        target(
          type: scope['type'],
          target: scope['target'],
          in_scope: false,
          bounty: false,
          updated_at: nil,
          severity: nil,
          instruction: nil
        )
      end

      program_hash(
        platform: 'yeswehack',
        id: program['id'],
        handle: nil,
        name: program['name'],
        url: program['url'],
        offers_bounty: program['bounty'],
        submission_state: nil,
        managed: program['managed'],
        first_started_at: nil,
        last_updated_at: program['last_update_at'],
        last_activity_at: nil,
        reports_count: program['reports_count'],
        resolved_reports_count: nil,
        total_bounty_amount: nil,
        bounty_min: program['min_bounty'],
        bounty_max: program['max_bounty'],
        targets: in_scope + out_of_scope
      )
    end

    def normalize_federacy(program)
      in_scope = program.dig('targets', 'in_scope').to_a.map do |scope|
        target(
          type: scope['type'],
          target: scope['target'],
          in_scope: true,
          bounty: scope['bounty'] == 'money',
          updated_at: nil,
          severity: scope['impact'],
          instruction: nil
        )
      end
      out_of_scope = program.dig('targets', 'out_of_scope').to_a.map do |scope|
        target(
          type: scope['type'],
          target: scope['target'],
          in_scope: false,
          bounty: false,
          updated_at: nil,
          severity: nil,
          instruction: nil
        )
      end

      program_hash(
        platform: 'federacy',
        id: program['id'],
        handle: nil,
        name: program['name'],
        url: program['url'],
        offers_bounty: program['offers_awards'],
        submission_state: nil,
        managed: program['managed'],
        first_started_at: program['created_at'],
        last_updated_at: nil,
        last_activity_at: nil,
        reports_count: nil,
        resolved_reports_count: nil,
        total_bounty_amount: nil,
        bounty_min: program['award_low'],
        bounty_max: program['award_critical'],
        targets: in_scope + out_of_scope
      )
    end

    def program_hash(platform:, id:, handle:, name:, url:, offers_bounty:, submission_state:, managed:,
                     first_started_at:, last_updated_at:, last_activity_at:, reports_count:,
                     resolved_reports_count:, total_bounty_amount:, bounty_min:, bounty_max:, targets:)
      {
        'platform' => platform,
        'id' => id,
        'handle' => handle,
        'name' => name,
        'url' => url,
        'offers_bounty' => offers_bounty,
        'submission_state' => submission_state,
        'managed' => managed,
        'first_started_at' => to_iso8601(first_started_at),
        'last_updated_at' => to_iso8601(last_updated_at),
        'last_activity_at' => to_iso8601(last_activity_at),
        'reports_count' => reports_count,
        'resolved_reports_count' => resolved_reports_count,
        'total_bounty_amount' => total_bounty_amount,
        'bounty_min' => bounty_min,
        'bounty_max' => bounty_max,
        'targets' => targets
      }
    end

    def target(type:, target:, in_scope:, bounty:, updated_at:, severity:, instruction:)
      {
        'type' => type,
        'target' => target,
        'in_scope' => in_scope,
        'bounty' => bounty,
        'updated_at' => to_iso8601(updated_at),
        'severity' => severity,
        'instruction' => instruction
      }
    end

    def bounty_tier?(impact)
      ['Tier 1', 'Tier 2', 'Tier 3'].include?(impact)
    end

    def intigriti_offers_bounty?(program, in_scope)
      values = [program['min_bounty'], program['max_bounty']].map { |money| money_value(money) }.compact
      return values.any?(&:positive?) unless values.empty?

      in_scope.any? { |scope| scope['bounty'] == true }
    end

    def money_value(money)
      money['value'] if money.is_a?(Hash)
    end

    def to_iso8601(value)
      case value
      when String then Time.parse(value).utc.iso8601
      when Integer, Float then Time.at(value).utc.iso8601
      end
    rescue ArgumentError
      nil
    end

    def to_float(value)
      Float(value)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
