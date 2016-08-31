class ConfigTest

  require 'archivesspace-api-utility'
  require './as_config.rb'

  @@a = ArchivesSpaceApiUtility::ArchivesSpaceSession.new

  def archivesspace_connection
    puts
    print "testing ArchivesSpace connection..."
    begin
      path = '/repositories'
      response = @@a.get(path)
      if response.code.to_i == 200
        print "OK"
      else
        print "ERROR"
        puts
        puts response.body
      end
    rescue Exception => e
      print "error"
      puts e
    end
    puts
  end


end

test = ConfigTest.new
test.archivesspace_connection
