# frozen_string_literal: true

require 'json'
require 'ssrf_filter'
require 'uri'

module BountyTargets
  class YesWeHack
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
        %w[api web-application].include?(scope[:type])
      end.map do |scope|
        scope[:target]
      end
    end

    private

    def directory_index
      uri = URI('https://api.yeswehack.com/programs')
      page = 1
      programs = []
      ::Kernel.loop do
        uri.query = ::URI.encode_www_form(page: page)
        result = ::JSON.parse(SsrfFilter.get(uri).body)
        page += 1
        programs.concat(result['items'].map do |program|
          {
            archived: program['archived'],
            bounty: program['bounty'],
            disabled: program['disabled'],
            event: program['event'],
            gift: program['gift'],
            id: program['slug'],
            last_update_at: program['last_update_at'],
            managed: program['managed'],
            max_bounty: program['bounty_reward_max'],
            min_bounty: program['bounty_reward_min'],
            name: program['title'],
            public: program['public'],
            reports_count: program['reports_count'],
            scopes_count: program['scopes_count'],
            status: program['status'],
            url: "https://yeswehack.com/programs/#{program['slug']}",
            vdp: program['vdp']
          }
        end)

        break unless result['items'].length == result['pagination']['results_per_page']
      end

      programs
    end

    def program_scopes(program)
      uri = ::URI.parse('https://api.yeswehack.com/programs/' + ::URI.encode_www_form_component(program[:id]))
      response = ::JSON.parse(SsrfFilter.get(uri).body)
      {
        stats: response['stats'],
        targets: {
          in_scope: (response['scopes'] || []).map do |scope|
            {
              asset_value: scope['asset_value'],
              report_count: scope['report_count'],
              target: scope['scope'],
              type: scope['scope_type']
            }
          end,
          out_of_scope: (response['out_of_scope'] || []).map do |scope|
            {
              target: scope,
              type: 'other'
            }
          end
        }
      }
    end
  end
end
