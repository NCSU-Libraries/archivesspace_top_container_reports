require_relative './reports_config.rb'

module ArchivesSpaceApiUtility

  class << self
    attr_accessor :configuration
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration)
  end

  class Configuration
    include ReportsConfig
    attr_accessor :host, :port, :username, :password, :https

    def initialize
      @config = config_values
      @host = @config[:archivesspace_host] || 'localhost'
      @port = @config[:archivesspace_backend_port] || 8089
      @username = @config[:archivesspace_username] || 'admin'
      @password = @config[:archivesspace_password] || 'admin'
      @https = @config[:archivesspace_https] || false
    end

  end

end
