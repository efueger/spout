require 'openssl'
require 'net/http'
require 'json'

module Spout
  module Helpers
    class JsonRequestGeneric
      class << self
        def post(url, *args)
          new(url, *args).post
        end

        def patch(url, *args)
          new(url, *args).patch
        end
      end

      attr_reader :url

      def initialize(url, args)
        @params = nested_hash_to_params(args)
        @url = URI.parse(url)

        @http = Net::HTTP.new(@url.host, @url.port)
        if @url.scheme == 'https'
          @http.use_ssl = true
          @http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
      rescue => e
        puts "Error sending JsonRequestGeneric: #{e}".colorize(:red)
      end

      def post
        response = @http.start do |http|
          http.post(@url.path, @params.join('&'))
        end
        [JSON.parse(response.body), response]
      rescue => e
        puts "POST ERROR: #{e}".colorize(:red)
        nil
      end

      def patch
        @params.merge({'_method' => 'patch'})
        post
      end

      def nested_hash_to_params(args)
        args.collect do |key, value|
          key_value_to_string(key, value, nil)
        end
      end

      def key_value_to_string(key, value, scope = nil)
        current_scope = (scope ? "#{scope}[#{key}]" : key)
        if value.is_a? Hash
          value.collect do |k,v|
            key_value_to_string(k, v, current_scope)
          end.join('&')
        elsif value.is_a? Array
          value.collect do |v|
            key_value_to_string('', v, current_scope)
          end
        else
          "#{current_scope}=#{value}"
        end
      end
    end
  end
end