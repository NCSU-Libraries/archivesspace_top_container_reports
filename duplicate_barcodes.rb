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


  def generate
    barcodes = get_barcodes
    barcodes.each do |b|
      if has_duplicates(b)
        puts "#{ b } has duplicates"
      end
    end
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

