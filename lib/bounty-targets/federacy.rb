# frozen_string_literal: true

require 'json'
require 'ssrf_filter'
require 'uri'

module BountyTargets
  class Federacy
    def scan
      return @scan_results if instance_variable_defined?(:@scan_results)

      @scan_results = directory_index.map do |program|
        program.merge(program_scopes(program))
      end.sort_by do |program|
        program[:name]
      end
    end

    def uris
      scan.flat_map do |program|
        program[:targets][:in_scope]
      end.select do |scope|
        scope[:type] == 'website'
      end.map do |scope|
        scope[:target]
      end
    end

    private

    def directory_index
      programs = ::JSON.parse(SsrfFilter.get(::URI.parse('https://www.federacy.com/api/public_programs')).body)
      programs.map do |program|
        {
          award_critical: program['award_critical'],
          award_high: program['award_high'],
          award_low: program['award_low'],
          award_medium: program['award_medium'],
          created_at: program['created_at'],
          id: program['id'],
          managed: program['managed'],
          name: program['program_name'],
          offers_awards: program['offers_awards'],
          public: program['public'],
          url: "https://www.federacy.com/#{program['slug']}"
        }
      end
    end

    def program_scopes(program)
      uri = ::URI.parse("https://www.federacy.com/api/public_programs/#{program[:id]}/program_scopes")
      response = ::JSON.parse(SsrfFilter.get(uri).body)
      scopes = response.group_by { |scope| scope['in_scope'] }
      {
        targets: {
          in_scope: scopes_to_hashes(scopes[true]),
          out_of_scope: scopes_to_hashes(scopes[false])
        }
      }
    end

    def scopes_to_hashes(scopes)
      Array(scopes).map do |scope|
        {
          bounty: scope['bounty'],
          identifier_type: scope['identifier_type'],
          impact: scope['impact'],
          target: scope['identifier'],
          type: scope['scope_type']
        }
      end
    end
  end
end
