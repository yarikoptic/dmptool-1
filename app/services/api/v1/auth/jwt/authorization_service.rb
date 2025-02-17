# frozen_string_literal: true

module Api
  module V1
    module Auth
      module Jwt
        # Class to handle User authorization
        class AuthorizationService
          def initialize(headers: {})
            @headers = headers.nil? ? {} : headers
            @errors = ActiveSupport::HashWithIndifferentAccess.new
          end

          def call
            client
          end

          attr_reader :errors

          private

          # Lookup the Client bassed on the client_id embedded in the JWT
          # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
          def client
            return @api_client if @api_client.present?

            token = decoded_auth_token
            # If the token is missing or invalid then set the client to nil
            errors[:token] = _('Invalid token') if token.blank?
            @api_client = nil unless token.present? && token[:client_id].present?
            return @api_client unless token.present? && token[:client_id].present?

            @api_client = ApiClient.where(client_id: token[:client_id]).first
            return @api_client if @api_client.present?

            @api_client = User.where(email: token[:client_id]).first
          end
          # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity

          def decoded_auth_token
            return @token if @token.present?

            @token = JsonWebToken.decode(token: http_auth_header)
            @token
          rescue JWT::ExpiredSignature
            errors[:token] = _('Token expired')
            nil
          end

          # Extract the token from the Authorization header
          def http_auth_header
            hdr = @headers[:Authorization]
            errors[:token] = _('Missing token') if hdr.blank?
            return nil if hdr.blank?

            hdr.split.last
          end
        end
      end
    end
  end
end
