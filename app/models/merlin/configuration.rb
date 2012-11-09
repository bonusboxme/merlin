require 'yaml'

module Merlin
  class Configuration
    attr_reader :raw

    def initialize(config_file_path, environment = ::Rails.env, connection = nil)
      @environment = environment
      @local_raw = from_file(config_file_path)
      @remote_raw = merlin_server ? from_server(connection) : {}
      @raw = @remote_raw.deep_merge(@local_raw)
      @struct = OpenStruct.deep(raw.clone, true)
    end

    def method_missing(name, *args, &block)
      @struct.send(name, *args, &block)
    end

    private

    def from_file(config_file_path)
      YAML.load(File.read(config_file_path))[@environment.to_s]
    end

    def from_server(connection = nil)
      connection ||= Faraday.new(merlin_server) do |conn|
        conn.response :json, :content_type => /\bjson$/
        conn.adapter Faraday.default_adapter
      end

      response = connection.get "/config/#{@environment}.json"
      if response.status == 200
        result = response.body
        dump_config(result) unless production_or_staging
        result
      else
        {}
      end
    rescue Faraday::Error::ConnectionFailed => e
      if production_or_staging
        raise e
      else
        restore_config
      end
    end

    def production_or_staging
      ["production", "staging"].include?(::Rails.env)
    end

    def dump_config(config)
      print_message "ONLINE - dump config in '#{dump_filepath}'."
      File.open(dump_filepath, "w") { |file| file.puts(YAML.dump(config)) }
    end

    def restore_config
      print_message "OFFLINE - restore config from '#{dump_filepath}'."
      File.open(dump_filepath, "r") { |file| YAML.load(file) }
    end

    def print_message(message)
      merlin_message = "MERLIN: #{message}"
      Rails.logger.warn(merlin_message)
      puts merlin_message
    end

    def dump_filepath
      File.join(::Rails.root, "tmp", "merlin_offline_dump.yml")
    end

    def merlin_server
      @local_raw['merlin']
    end
  end
end
