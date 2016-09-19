require 'rubygems'
require 'mysql2'
require 'net/ssh/gateway'
require_relative 'config/reports_config.rb'
require_relative 'config/mysql_connect.rb'
require 'fileutils'


class BarcodeConflictsReport

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


  def top_container_barcodes_query(resource_id)
    "select a.root_record_id as resource_id,
      ev.value as top_container_type,
      c.id as container_id,
      c.indicator_1 as top_container_value,
      c.barcode_1 as barcode,
      i.archival_object_id,
      i.id as instance_id,
      r.title as resource_title
      from instance i
      join container c on c.instance_id = i.id
      join archival_object a on a.id = i.archival_object_id
      join resource r on r.id = a.root_record_id
      join enumeration_value ev on ev.id = c.type_1_id
      where a.root_record_id = #{ resource_id }
      order by ev.value, c.indicator_1"
  end


  def check_top_container_barcodes(resource_id)

    top_containers = {}
    resource_title = nil
    q = top_container_barcodes_query(resource_id)

    results = @@mysql_client.query(q)

    results.each do |r|
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

      (top_containers[top] ||= []) << [ r['barcode'], data ]
    end

    top_containers.each do |k,v|
      barcodes = v.map { |vv| vv[0] }
      barcodes.uniq!
      if barcodes.length > 1

        entry = {
          barcodes: {}
        }

        barcodes.each do |b|
          entry[:barcodes][b] = {
            archival_object_id: [],
            container_id: [],
            instance_id: []
          }
        end

        v.each do |vv|
          data = vv[1]
          barcode = vv[0]
          entry[:barcodes][barcode][:archival_object_id] << data[:archival_object_id]
          entry[:barcodes][barcode][:container_id] << data[:container_id]
          entry[:barcodes][barcode][:instance_id] << data[:instance_id]
        end

        @report_entries[ resource_id ] ||= {
          resource_title: resource_title
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
      check_top_container_barcodes(resource_id)
    end

    if !Dir.exist?('reports')
      Dir.mkdir('reports')
    end

    @report_filepath = "reports/barcode_conflicts.html"

    f = File.new("./#{ @report_filepath }",'w')

    f.puts "<html>"
    f.puts "<head><style>\n"
    f.puts "body { font-family: helvetica, sans-serif; }\n
      main { max-width: 1000px; margin: 0 auto; }\n"
    f.puts "</style></head>"
    f.puts "<body>"
    f.puts "<main>"
    f.puts "<h1>Top containers with barcode conflicts</h1>"

    aspace_root = "#{ @@config[:archivesspace_https] ? 'https' : 'http' }://#{ @@config[:archivesspace_host] }:#{ @@config[:archivesspace_frontend_port] }"

    @report_entries.each do |resource_id, v|
      resource_url = "#{ aspace_root }/resources/#{ resource_id }"
      f.puts "<h2><a href='#{ resource_url }' target='_blank'>#{ v[:resource_title] }</a></h2>"
      f.puts "<ul>"
      v[:top_containers].each do |top_container, data|
        f.puts "<li>#{ top_container }"
        f.puts "<ul>"
        data[:barcodes].each do |barcode, bdata|
          f.puts "<li>#{ !(barcode.nil? || barcode.empty?) ? barcode.gsub(/\&/,'&amp;') : '[BLANK]' }"
          f.puts "<ul>"

          bdata[:archival_object_id].each do |aoid|
            ao_url = "#{ resource_url }#tree::archival_object_#{ aoid }"
            f.puts "<li><a href='#{ ao_url }' target='_blank'>#{ ao_url }</a></li>"
          end

          f.puts "</ul>"
          f.puts "</li>"
        end
        f.puts "</ul>"
        f.puts "</li>"
      end
      f.puts "</ul>"
    end

    f.puts "</main>\n</body>\n</html>"

    f.close

    puts "Report complete - see #{ @report_filepath }"
  end

end

report = BarcodeConflictsReport.new
report.generate
