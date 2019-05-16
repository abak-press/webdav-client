require 'uri'
require 'httparty'

module Net
  module Webdav
    class Client
      include HTTParty

      MAX_TIMEOUT = 30

      attr_reader :host, :username, :password, :url, :http_auth_types, :timeout

      def initialize(url, options = {})
        uri = URI.parse(url)

        @host = "#{uri.scheme}://#{uri.host}#{uri.port.nil? ? "" : ":#{uri.port}"}"
        @http_auth_types = options[:http_auth_types] || :basic

        if uri.userinfo
          @username, @password = uri.userinfo.split(":")
        else
          @username = options[:username]
          @password = options[:password]
        end

        @url = URI.join(@host, uri.path).to_s
        @timeout = options.fetch(:timeout, MAX_TIMEOUT)
      end

      # Public: HEAD, check if file exists
      #
      # path - String, path to file on server
      #
      # Returns: Boolean
      def file_exists?(path)
        response = self.class.head(File.join('/', path), request_options)
        response.code >= 200 && response.code < 300
      end

      # Public: GET file, saves path to local_file_path
      #
      # path - String, path to file on server
      # local_file_path - String, file path to save on disk
      #
      # Returns: nothing
      def get_file(path, local_file_path)
        path = File.join('/', path)
        response = nil
        File.open(local_file_path, "w") do |file|
          file.binmode if file.respond_to?(:binmode)
          response = self.class.get(path, request_options.merge!(stream_body: true)) do |fragment|
            file.write(fragment)
          end
        end
        notify_of_error(response, "getting file. #{path}") if response && response.code != 200
      end

      # Public: PUT file
      #
      # path - String, path to file on server
      # file - File, file for save on server
      # crate_path - Boolean, true if need create path
      #
      # Returns Fixnum, status code, 201 || 204, if success
      def put_file(path, file, create_path = false)
        path = File.join('/', path)
        response = self.class.put(path, request_options.merge!(
          body_stream: file,
          headers: {
            'Content-Length' => file.size.to_s
          }
        ))

        if response.code != 201 && response.code != 204
          notify_of_error(response, "creating(putting) file. File path: #{path}")
        end

        response.code
      end

      # Public: DELETE file by path
      #
      # path - String, path to file on server
      #
      # Returns Boolean, always true
      def delete_file(path)
        path = File.join('/', path)
        raise ArgumentError if path == '/'
        self.class.delete(path, request_options)
      end

      private

      def request_options
        options = {
          base_uri: @url,
          timeout: @timeout
        }
        case http_auth_types
        when :basic
          if username && password
            options[:basic_auth] = {username: username, password: password}
          end
        end
        options
      end

      def notify_of_error(response, action)
        raise "Error in WEBDav Client while #{action} with error: #{response.code}"
      end

      def full_url(path)
        URI.join(@url, path).to_s
      end
    end
  end
end
