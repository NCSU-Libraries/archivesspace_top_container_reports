class MissingLocationsReport

  require 'rubygems'
  require 'mysql2'
  require 'net/ssh/gateway'
  require_relative 'config/reports_config.rb'
  require_relative 'config/mysql_connect.rb'
  require 'fileutils'

  include MysqlConnect
  include ReportsConfig

  @@config = config_values
  @@mysql_client = mysql_client

  def initialize
    @report_entries = {}
  end

  def get_resource_ids
    ids = []
    results = @@mysql_client.query("SELECT id FROM resource where id IS NOT NULL")
    results.each { |r| ids << r['id'] }
    ids
  end


  def top_container_locations_query(resource_id)
    "select a.root_record_id as resource_id,
    ev.value as top_container_type,
    c.id as container_id,
    c.indicator_1 as top_container_value,
    c.barcode_1 as barcode, h.location_id,
    l.title as location_title,
    i.archival_object_id, i.id as instance_id,
    CONCAT('/repositories/',r.repo_id,'/resources/',r.id) as resource_uri,
    l.id as location_id,
    r.title as resource_title
    from instance i
    join container c on c.instance_id = i.id
    left join housed_at_rlshp h on h.container_id = c.id
    join archival_object a on a.id = i.archival_object_id
    join resource r on r.id = a.root_record_id
    join enumeration_value ev on ev.id = c.type_1_id
    left join location l on l.id = h.location_id
    where a.root_record_id = #{ resource_id }
    order by ev.value, c.indicator_1"
  end


  def check_top_container_locations(resource_id)
    top_containers = {}
    q = top_container_locations_query(resource_id)

    results = @@mysql_client.query(q)

    location_titles = {}
    resource_uri = nil
    resource_title = nil

    results.each do |r|

      resource_uri ||= r['resource_uri']
      resource_title ||= r['resource_title']

      if r['top_container_type'] && r['top_container_value']
        top = r['top_container_type'] + ' ' + r['top_container_value']
      elsif r['top_container_type'] || r['top_container_value']
        top = r['top_container_type'] ? r['top_container_type'] : r['top_container_value']
      end

      data = {
        instance_id: r['instance_id'],
        archival_object_id: r['archival_object_id'],
        container_id: r['container_id'],
        resource_id: resource_id,
        location_title: r['location_title']
      }

      location_titles[ r['location_id'] ] = r['location_title']

      (top_containers[top] ||= []) << [ r['location_id'], data ]
    end

    top_containers.each do |k,v|

      location_ids = v.map { |vv| vv[0] }
      location_ids.uniq!
      if location_ids.length > 1

        entry = {
          locations: {}
        }

        location_ids.each do |lid|
          entry[:locations][lid] = {
            title: location_titles[lid],
            archival_object_id: [],
            container_id: [],
            instance_id: []
          }
        end

        v.each do |vv|
          data = vv[1]
          lid = vv[0]
          entry[:locations][lid][:archival_object_id] << data[:archival_object_id]
          entry[:locations][lid][:container_id] << data[:container_id]
          entry[:locations][lid][:instance_id] << data[:instance_id]
        end

        @report_entries[ resource_id ] ||= {
          resource_title: resource_title,
          resource_uri: resource_uri,
        }

        @report_entries[ resource_id ][ :top_containers ] ||= {}

        @report_entries[ resource_id ][ :top_containers ][k] = entry
      end
    end

    if @report_entries[ resource_id ]
      puts
      puts @report_entries[ resource_id ]
    end

  end


  def generate
    resource_ids = get_resource_ids

    resource_ids.each do |resource_id|
      check_top_container_locations(resource_id)
    end

    if !Dir.exist?('reports')
      Dir.mkdir('reports')
    end

    @report_filename = "reports/missing_locations.html"

    f = File.new("./#{ @report_filename }",'w')

    f.puts "<html>"
    f.puts "<head><style>\n"
    f.puts "body { font-family: helvetica, sans-serif; }\n
      main { max-width: 1000px; margin: 0 auto; }\n"
    f.puts "</style></head>"
    f.puts "<body>"
    f.puts "<main>"
    f.puts "<h1>Top containers with missing location</h1>"
    # f.puts fields.join("\t")

    aspace_root = "http://archives.lib.ncsu.edu:8180"

    @report_entries.each do |resource_id, v|
      resource_url = "#{ aspace_root }/resources/#{ resource_id }"

      # only include top containers with null location_id

      resource_heading = "<h2><a href='#{ resource_url }' target='_blank'>#{ v[:resource_title] }</a></h2>"

      container_list_items = ""

      v[:top_containers].each do |top_container, data|

        top_container_locations_list = ''

        has_empty_location = nil

        data[:locations].each do |location_id, ldata|
          if location_id
            top_container_locations_list += "\n<li><a href='#{ aspace_root }/locations/#{ location_id }' target='_blank'>#{ ldata[:title] }</a>"
          else
            top_container_locations_list += "\n<li>[ NULL ]"
            has_empty_location = true
          end
          top_container_locations_list += "\n<ul>"

          ldata[:archival_object_id].each do |aoid|
            ao_url = "#{ resource_url }#tree::archival_object_#{ aoid }"
            top_container_locations_list += "\n<li><a href='#{ ao_url }' target='_blank'>#{ ao_url }</a></li>"
          end

          top_container_locations_list += "\n</ul>\n</li>"
        end

        if !top_container_locations_list.empty? && has_empty_location
          container_list_items += "\n<li>#{ top_container }"
          container_list_items += "\n<ul>"
          container_list_items += top_container_locations_list
          container_list_items += "\n</ul>\n</li>"
        end
      end

      if !container_list_items.empty?
        container_list = "<ul>\n#{container_list_items}\n</ul>"
        f.puts resource_heading
        f.puts container_list
      end

    end

    f.puts "</main>\n</body>\n</html>"

    f.close

    puts "Report complete - see #{ @report_filename }"
  end

end

report = MissingLocationsReport.new
report.generate
