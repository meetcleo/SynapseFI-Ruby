require 'rest-client'
require 'json'

module SynapsePayRest
  class HTTPClient
    attr_accessor :base_url, :config, :user_id

    # TODO: log responses as well as requests
    def initialize(config, base_url, user_id: nil, logging: false)
      @config = config
      @base_url = base_url
      RestClient.log = 'stdout' if logging
      @user_id = user_id
    end

    def headers
      user    = "#{config['oauth_key']}|#{config['fingerprint']}"
      gateway = "#{config['client_id']}|#{config['client_secret']}"
      headers = {
        :content_type => :json,
        :accept => :json,
        'X-SP-GATEWAY' => gateway,
        'X-SP-USER' => user,
        'X-SP-USER-IP' => config['ip_address']
      }
    end
    # to support old method name
    alias_method :get_headers, :headers

    # TODO: auto-generate fingerprint
    def update_headers(user_id: nil, oauth_key: nil, fingerprint: nil, client_id: nil, client_secret: nil, ip_address: nil)
      self.user_id            = user_id if user_id
      config['fingerprint']   = fingerprint if fingerprint
      config['oauth_key']     = oauth_key if oauth_key
      config['client_id']     = client_id if client_id
      config['client_secret'] = client_secret if client_secret
      config['ip_address']    = ip_address if ip_address
    end

    def post(path, payload)
      response = with_error_handling { RestClient.post(full_url(path), payload.to_json, headers) }
      JSON.parse(response)
    end

    def patch(path, payload)
      response = with_error_handling { RestClient.patch(full_url(path), payload.to_json, headers) }
      JSON.parse(response)
    end

    def get(path)
      response = with_error_handling { RestClient.get(full_url(path), headers) }
      JSON.parse(response)
    end

    def delete(path)
      response = with_error_handling { RestClient.delete(full_url(path), headers) }
      JSON.parse(response)
    end

    private

    def full_url(path)
      "#{base_url}#{path}"
    end

    # TODO: see if there's a better way to do this
    def with_error_handling
      yield
    rescue RestClient::Exception => e
      body = JSON.parse(e.response.body)
      raise Error.error_from_response(body, e.response.code)
    end
  end
end
