require 'rubygems'
require 'mysql2'
require 'csv'
require 'net/ssh/gateway'
require 'json'

gateway = Net::SSH::Gateway.new('archives.lib.ncsu.edu', 'trthorn2', :password => "D1nklage")
gateway.open('127.0.0.1', 3306, 3307)

$mysql_client = Mysql2::Client.new(:host => "127.0.0.1", :username => "archivesspace",
  :password => "arch1ve55pac3", :database => "archivesspace", :port => 3307)


$fields = ['indicator_1','type_1_id','resource_url','resource_identifier','top_container','barcode','location']

$q_common = "SELECT
  c.indicator_1,
  c.type_1_id,
  c.barcode_1 as barcode,
  CONCAT('http://archives.lib.ncsu.edu:8180/resources/',r.id) as resource_url,
  r.identifier,
  CONCAT(ev.value,' ',c.indicator_1) as top_container,
  l.title as location
  FROM container c
  JOIN housed_at_rlshp h on h.container_id = c.id
  JOIN location l on l.id = h.location_id
  JOIN instance i on i.id = c.instance_id
  JOIN enumeration_value ev on ev.id = c.type_1_id
  JOIN archival_object ao ON ao.id = i.archival_object_id
  JOIN resource r on r.id = ao.root_record_id"

def add_resource_identifier(data)
  identifiers = data['identifier']
  ids = JSON.parse(identifiers)
  data['resource_identifier'] = ids[0]
  data
end

def get_data_for_archival_object(archival_object_ids)
  q = "#{ $q_common } WHERE ao.id IN (#{ archival_object_ids.join(',') })"
  results = $mysql_client.query(q)
  results.to_a.map { |r| add_resource_identifier(r) }
end

def get_data_for_barcode(barcodes)
  q = "#{ $q_common } WHERE c.barcode_1 IN ('#{ barcodes.join("','") }')"
  results = $mysql_client.query(q)
  results.to_a.map { |r| add_resource_identifier(r) }
end


def get_top_container_data(archival_object_ids)
  data = []
  barcodes = []
  ao_data = get_data_for_archival_object(archival_object_ids)
  data += ao_data
  ao_data.each do |hash|
    if hash['barcode']
      barcodes << hash['barcode']
    end
  end

  b_data = get_data_for_barcode(barcodes)
  data += b_data

  data.uniq
end




top_container_data = []
ids = File.open('./archival_object_ids.txt')

i = 1

batch = []

ids.each_line do |l|
  puts l
  l.strip!
  batch << l
  if i == 100
    batch_data = get_top_container_data(batch)
    puts batch_data.inspect
    top_container_data += batch_data
    i = 1
  else
    i += 1
  end
end


top_container_data.uniq!

report = File.new('./duplicate_barcodes.csv','w')
report.puts($fields.join(','))
top_container_data.each do |d|
  line_elements = []
  $fields.each do |f|

    line_elements << (d[f] || '')
  end
  report.puts('"' + line_elements.join('","') + '"')
end

