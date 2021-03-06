require 'base64'
require 'yaml'
require 'zlib'

module Settei
  module Loaders
    # Loader designed to load hash from environment variable and YAML files.
    # After initialization, call {#load} to load hash into memory,
    # then call {#as_hash}, {#as_env_value}, or {#as_env_assignment} to obtain the results.
    # e.g. `loader.load(:production).as_hash`
    class SimpleLoader
      attr_reader :env_name

      # @param dir [String] path of directory containing config YAML files
      # @param env_name [String] name for environment variable
      def initialize(dir: nil, env_name: 'APP_CONFIG')
        @dir = dir
        @env_name = env_name
      end

      # Loads yaml file into memory.
      # If `ENV[@env_name]` exists, loader loads from it,
      # otherwise load from YAML file.
      #
      # YAML file is picked based on provided `environment`.
      # If environment is not specified,
      # or specified environment file does not exist,
      # default.yml is loaded.
      #
      # @param environment [String] application environment (e.g. production/test)
      # @return [self] for further chaining
      def load(environment = nil)
        if !ENV[@env_name].nil?
          @yaml = Zlib::Inflate.inflate(
            Base64.strict_decode64(ENV[@env_name])
          )
        else
          if environment
            env_specific_file_path = "#{@dir}/#{environment}.yml"
            if File.exist?(env_specific_file_path)
              file_path = env_specific_file_path
            end
          end
          file_path ||= "#{@dir}/default.yml"

          @yaml = open(file_path).read
        end

        self
      end

      # @return [Hash]
      def as_hash
        ensure_loaded!

        YAML.load(@yaml)
      end

      # @return [String] serialized config hash, for passing as environment variable
      def as_env_value
        ensure_loaded!

        Base64.strict_encode64(
          Zlib::Deflate.deflate(@yaml)
        )
      end

      # Convenience method for outputting "NAME=VALUE" in one call.
      # @return [String] {#as_env_value} with assignment to `env_name`
      def as_env_assignment
        ensure_loaded!

        "#{@env_name}=#{as_env_value}"
      end

      private

      def ensure_loaded!
        if !@yaml
          raise 'Call `load` first to load YAML into memory.'
        end
      end
    end
  end
end