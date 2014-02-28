require 'heroku-api'
require 'rendezvous'
require 'paratrooper/local_api_key_extractor'

module Paratrooper
  class HerokuWrapper
    attr_reader :api_key, :app_name, :heroku_api, :key_extractor, :rendezvous

    def initialize(app_name, options = {})
      @app_name      = app_name
      @key_extractor = options[:key_extractor] || LocalApiKeyExtractor
      @api_key       = options[:api_key] || key_extractor.get_credentials
      @heroku_api    = options[:heroku_api] || Heroku::API.new(api_key: api_key)
      @rendezvous    = options[:rendezvous] || Rendezvous
    end

    def app_restart
      heroku_api.post_ps_restart(app_name)
    end

    def app_maintenance_off
      app_maintenance('0')
    end

    def app_maintenance_on
      app_maintenance('1')
    end

    def app_url
      app_domain_name
    end

    def run_migrations
      run_task('rake db:migrate')
    end

    def run_task(task_name)
      data = heroku_api.post_ps(app_name, task_name, attach: 'true').body
      rendezvous.start(url: data['rendezvous_url'])
    end

    def last_deploy_commit
      data = heroku_api.get_releases(app_name).body
      return nil if data.empty?
      data.last['commit']
    end

    private
    def app_domain_name
      if custom_domain_response
        custom_domain_response['domain']
      else
        default_domain_name
      end
    end

    def app_maintenance(flag)
      heroku_api.post_app_maintenance(app_name, flag)
    end

    def default_domain_name
      heroku_api.get_app(app_name).body['domain_name']['domain']
    end

    def custom_domain_response
      @custom_domain_response ||= heroku_api.get_domains(app_name).body.last
    end
  end
end
