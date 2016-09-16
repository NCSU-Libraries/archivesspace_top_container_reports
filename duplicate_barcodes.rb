require 'rubygems'
require 'mysql2'
require 'net/ssh/gateway'
require_relative 'config/reports_config.rb'
require_relative 'config/mysql_connect.rb'
require 'fileutils'

class DuplicateBarcodesReport

  include MysqlConnect
  include ReportsConfig

  @@config = config_values
  @@mysql_client = mysql_client

  def initialize
    @duplicate_barcodes = []
    @report_entries = {}
  end


  def get_barcodes
    q = "SELECT DISTINCT barcode_1 FROM container WHERE barcode_1 IS NOT NULL"
    results = @@mysql_client.query(q)
    results.map { |r| r['barcode_1'] }
  end


  def get_unique_containers_for_barcode(barcode)
    q = "select distinct ao.root_record_id, i.resource_id, i.accession_id, c.type_1_id, c.indicator_1, c.barcode_1
      from container c
      join instance i on i.id = c.instance_id
      left join archival_object ao on ao.id = i.archival_object_id
      left join resource r on r.id = i.resource_id
      where c.barcode_1 = '#{ barcode }'"
    @@mysql_client.query(q)
  end


  def get_container_data_for_barcode(barcode)
    q = "select c.indicator_1 as top_container_indicator,
      ev.value as top_container_type,
      i.resource_id, i.archival_object_id, i.accession_id
      from container c
      join instance i on i.id = c.instance_id
      left join enumeration_value ev on ev.id = c.type_1_id
      where c.barcode_1 = '#{ barcode }'"
    @@mysql_client.query(q)
  end


  def has_duplicates(barcode)
    dups = false
    container_results = get_unique_containers_for_barcode(barcode)
    if container_results.to_a.length > 1
      verify_array = []
      container_results.each do |r|
        hash = {
          resource_id: r['root_record_id'] ? r['root_record_id'] : r['resource_id'],
          accession_id: r['accession_id'],
          indicator_1: r['indicator_1'],
          type_1_id: r['type_1_id']
        }
        verify_array << hash
      end
      verify_array.uniq!
      if verify_array.length > 1
        dups = true
      end
    end


    dups
  end


  def get_resource_data(resource_id)
    q = "SELECT * from resource where id=#{ resource_id } LIMIT 1"
    results = @@mysql_client.query(q)
    results.first
  end


  def get_resource_data_from_archival_object(archival_object_id)
    q = "SELECT r.* from resource r
      JOIN archival_object ao on ao.root_record_id = r.id
      where ao.id=#{ archival_object_id } LIMIT 1"
    results = @@mysql_client.query(q)
    results.first
  end


  def get_accession_data(accesion_id)
    q = "SELECT * from accession where id=#{ accesion_id } LIMIT 1"
    results = @@mysql_client.query(q)
    results.first
  end


  def generate_report_data
    @duplicate_barcodes.each do |b|
      @report_entries[b] = {}
      container_data = get_container_data_for_barcode(b)
      container_data.each do |c_data|
        top_container = "#{ c_data['top_container_type'] } #{ c_data['top_container_indicator']}"
        if c_data['resource_id'] || c_data['archival_object_id']
          if c_data['resource_id']
            record_url_fragment = "/resources/#{ c_data['resource_id'] }"
            resource_data = get_resource_data(c_data['resource_id'])
            key = record_url_fragment
          else
            resource_data = get_resource_data_from_archival_object(c_data['archival_object_id'])
            record_url_fragment = "/resources/#{ resource_data['id'] }#tree::archival_object_"
            key = "/resources/#{ resource_data['id'] }"
          end
          @report_entries[b][key] ||= {
            title: resource_data['title'],
            type: 'resource',
            containers: {}
          }

        elsif c_data['accession_id']
          record_url_fragment = "/accessions/#{ c_data['accession_id'] }"
          key = record_url_fragment
          accession_data = get_accession_data(c_data['accession_id'])
          @report_entries[b][key] ||= {
            title: accession_data['title'],
            type: 'accession',
            containers: {}
          }
        end
        @report_entries[b][key][:containers][top_container] ||= []
        @report_entries[b][key][:containers][top_container] << record_url_fragment
      end
    end
  end


  ### FOR TESTING ONLY - DELETE! ###
  def test_find_duplicates
    barcodes = get_barcodes
    i = 0
    barcodes.each do |b|
      if i == 3
        break
      else
        if has_duplicates(b)
          @duplicate_barcodes << b
          puts "#{ b } has duplicates"
          i += 1
        end
      end
    end
  end


  def find_duplicates
    barcodes = get_barcodes
    barcodes.each do |b|
      if has_duplicates(b)
        @duplicate_barcodes << b
        puts "#{ b } has duplicates"
      end
    end
  end


  def generate_report_html
    @report_filepath = "reports/duplicate_barcodes.html"
    @aspace_root = "#{ @@config[:archivesspace_https] ? 'https' : 'http' }://#{ @@config[:archivesspace_host] }:#{ @@config[:archivesspace_frontend_port] }"
    f = File.new("./#{ @report_filepath }",'w')
    f.puts "<html>"
    f.puts "<head><style>\n"
    f.puts "body { font-family: helvetica, sans-serif; }\n
      main { max-width: 1000px; margin: 0 auto; }\n"
    f.puts "</style></head>"
    f.puts "<body>"
    f.puts "<main>"
    f.puts "<h1>Barcodes duplicated in different top containers</h1>"
    @report_entries.each do |barcode, records|
      f.puts "<h2>#{ barcode }</h2>"
      f.puts "<ul>"
      records.each do |uri, record_data|
        f.puts "<li>#{ record_data[:title] } (#{ record_data[:type] })"
        f.puts "<ul>"
        record_data[:containers].each do |top_container, url_fragments|
          f.puts "<li>#{ top_container }"
          f.puts "<ul>"
          url_fragments.each do |url_fragment|
            url = @aspace_root + url_fragment
            f.puts "<li><a href=\"#{ url }\" target=\"_blank\">#{ url }</a></li>"
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



  def generate
    test_find_duplicates
    generate_report_data
    generate_report_html
  end





end

report = DuplicateBarcodesReport.new
report.generate


# select distinct (concat(ao.root_record_id,'-',c.type_1_id,'-',c.indicator_1))
# from container c
# join instance i on i.id = c.instance_id
# join archival_object ao on ao.id = i.archival_object_id
# where c.barcode_1 = 'S02247998+'



# def add_resource_identifier(data)
#   identifiers = data['identifier']
#   ids = JSON.parse(identifiers)
#   data['resource_identifier'] = ids[0]
#   data
# end

# def get_data_for_archival_object(archival_object_ids)
#   q = "#{ $q_common } WHERE ao.id IN (#{ archival_object_ids.join(',') })"
#   results = $mysql_client.query(q)
#   results.to_a.map { |r| add_resource_identifier(r) }
# end

# def get_data_for_barcode(barcodes)
#   q = "#{ $q_common } WHERE c.barcode_1 IN ('#{ barcodes.join("','") }')"
#   results = $mysql_client.query(q)
#   results.to_a.map { |r| add_resource_identifier(r) }
# end


# def get_top_container_data(archival_object_ids)
#   data = []
#   barcodes = []
#   ao_data = get_data_for_archival_object(archival_object_ids)
#   data += ao_data
#   ao_data.each do |hash|
#     if hash['barcode']
#       barcodes << hash['barcode']
#     end
#   end

#   b_data = get_data_for_barcode(barcodes)
#   data += b_data

#   data.uniq
# end




# top_container_data = []
# ids = File.open('./archival_object_ids.txt')

# i = 1

# batch = []

# ids.each_line do |l|
#   puts l
#   l.strip!
#   batch << l
#   if i == 100
#     batch_data = get_top_container_data(batch)
#     puts batch_data.inspect
#     top_container_data += batch_data
#     i = 1
#   else
#     i += 1
#   end
# end


# top_container_data.uniq!

# report = File.new('./duplicate_barcodes.csv','w')
# report.puts($fields.join(','))
# top_container_data.each do |d|
#   line_elements = []
#   $fields.each do |f|

#     line_elements << (d[f] || '')
#   end
#   report.puts('"' + line_elements.join('","') + '"')
# end

