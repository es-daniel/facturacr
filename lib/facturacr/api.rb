require 'facturacr/api/document_status'

require 'base64'
require 'rest-client'
require 'json'

module FE
  class Api

    attr_accessor :authentication_endpoint, :document_endpoint, :username, :password, :client_id, :errors, :check_location,
                  :token, :refresh_token, :token_expiration, :refresh_token_expiration

    def initialize(configuration = nil)
      @configuration = configuration
      @authentication_endpoint = (configuration || FE.configuration).authentication_endpoint
      @document_endpoint = (configuration || FE.configuration).documents_endpoint
      @username = (configuration || FE.configuration).api_username
      @password = (configuration || FE.configuration).api_password
      @client_id = (configuration || FE.configuration).api_client_id
      @token = (configuration || FE.configuration).token
      @token_expiration = (configuration || FE.configuration).token_expiration
      @refresh_token = (configuration || FE.configuration).refresh_token
      @refresh_token_expiration = (configuration || FE.configuration).refresh_token_expiration
      @errors = {}
    end

    def authenticate
      check_token
      @configuration.save_config
    rescue => e
      puts "AUTH ERROR: #{e.message}".red
      raise e
    end

    def check_token
      response = if token.nil? || (DateTime.now.to_i > refresh_token_expiration.to_i)
                   new_token
                 elsif (refresh_token_expiration.to_i > DateTime.now.to_i) && (DateTime.now.to_i > token_expiration.to_i)
                   refresh_tokens
                 end
      if response
        current_date = Time.now.in_time_zone("Central America")
        @configuration.token = @token = JSON.parse(response)['access_token']
        @configuration.refresh_token =  @refresh_token = JSON.parse(response)['refresh_token']
        @configuration.token_expiration = @token_expiration = (current_date + (JSON.parse(response)['expires_in'].to_i - 4.minutes.to_i).seconds)
        @configuration.refresh_token_expiration = @refresh_token_expiration = (current_date + (JSON.parse(response)['refresh_expires_in'].to_i - 4.minutes.to_i).seconds)
      end
    end

    def new_token
      RestClient.post @authentication_endpoint, new_token_auth_data
    end

    def refresh_tokens
      RestClient.post @authentication_endpoint, refresh_token_auth_data
    end


    def send_document(payload)
      authenticate
      response = RestClient.post "#{@document_endpoint}/recepcion", payload.to_json, { Authorization: "bearer #{@token}", content_type: :json}
      if response.code.eql?(200) || response.code.eql?(202)
        @check_location = response.headers[:location]
        puts "CheckLocation: #{@check_location}"
        return true
      end
    rescue => e
      @errors[:request] = {message: e.message, response: e.response}
      return false
    end

    def get_document_status(key)
      authenticate
      response = RestClient.get "#{@document_endpoint}/recepcion/#{key}", { Authorization: "bearer #{@token}", content_type: :json }
      FE::Api::DocumentStatus.new(response)
    end

    def get_document(key)
      authenticate
      response = RestClient.get "#{@document_endpoint}/comprobantes/#{key}", { Authorization: "bearer #{@token}", content_type: :json }
      JSON.parse(response)
    end

    def get_documents
      authenticate
      response = RestClient.get "#{@document_endpoint}/comprobantes", { Authorization: "bearer #{@token}", content_type: :json }
      JSON.parse(response)
    end


    private



    def new_token_auth_data
      {
        grant_type: 'password',
        client_id: @client_id,
        username: @username,
        password: @password,
        client_secret: '',
        scope: ''
      }
    end

    def refresh_token_auth_data
      {
        grant_type: 'refresh_token',
        client_id: @client_id,
        refresh_token: @refresh_token
      }
    end

  end
end