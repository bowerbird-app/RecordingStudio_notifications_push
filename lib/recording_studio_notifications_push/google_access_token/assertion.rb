# frozen_string_literal: true

require "base64"
require "json"
require "openssl"

module RecordingStudioNotificationsPush
  class GoogleAccessToken
    class Assertion
      def initialize(credentials)
        @credentials = credentials
      end

      def to_s
        now = Time.now.to_i
        signing_input = "#{encode(header)}.#{encode(claims(now))}"
        signature = rsa_key.sign(OpenSSL::Digest.new("SHA256"), signing_input)
        "#{signing_input}.#{encode(signature)}"
      end

      private

      def header
        { alg: "RS256", typ: "JWT" }
      end

      def claims(now)
        {
          iss: @credentials.fetch("client_email"),
          scope: GoogleAccessToken::SCOPE,
          aud: @credentials.fetch("token_uri"),
          iat: now,
          exp: now + 3600
        }
      end

      def rsa_key
        OpenSSL::PKey::RSA.new(@credentials.fetch("private_key"))
      rescue OpenSSL::PKey::RSAError => e
        raise ArgumentError, "service account private_key is invalid: #{e.message}"
      end

      def encode(value)
        raw = value.is_a?(String) ? value : JSON.generate(value)
        Base64.urlsafe_encode64(raw, padding: false)
      end
    end
  end
end
