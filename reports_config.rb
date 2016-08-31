module ReportsConfig

  require 'yaml'

  def self.included receiver
    receiver.extend self
  end

  def config_values
    values = {}
    raw_values = YAML.load(File.read('./config.yml'))
    raw_values.each { |k,v| values[k.to_sym] = v }
    @config = values
  end

end


