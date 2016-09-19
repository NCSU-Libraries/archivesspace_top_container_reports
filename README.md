# archivesspace_top_container_reports
A set of Ruby scripts to report common problems with ArchivesSpace top containers in preparation for migration to version 1.5.x

## Requirements

1. These scripts assume that you are using MySQL for your ArchivesSpace database. They will not work with the demo database distributed with ArchivesSpace.
2. As these are Ruby scripts, you will need to have Ruby installed on the computer running the scripts (this does not need to be the same machine running ArchivesSpace or the database). Any relatively recent version of Ruby (1.9.x or later) should work.


## Installation

1. Clone or download this repository. Do not change the locations of the folders or files within the cloned/downloaded directory.
2. From within the base directory (archivesspace\_top\_container\_reports) run: `bundle install`

That should be it.

## Configuration

The file config/config.yml is where you will specify the info required to connect to your database and to provide links to your ArchivesSpace instance in the generated reports. Each line of this file is a different configuration option. Some of these are optional and can be left out, but DO NOT LEAVE BLANK SPACES BETWEEN LINES.

### ArchivesSpace information

The reports will provide links to your ArchivesSpace instance based on the values provided here.

* **archivesspace\_host:** The host name of the server where your AS instance is deployed.
* **archivesspace\_frontend\_port:** The port on which your ArchivesSpace front end (staff interface) is accessed (default is 8080)
* **archivesspace\_https:** Set to true if ArchivesSpace is accessed via https

### Database connection parameters

* **mysql\_host:** The host name of the MySQL server
* **mysql\_database:** The name of your ArchivesSpace database
* **mysql\_username:** User with permissions to query the ArchivesSapce database
* **mysql\_password:** Password associated with the MySQL user. If your database does not require a password for authentication you can remove this line and the scripts will attempt to connect without one.
* **mysql\_port:** Port used to access the MySQL database. This is typically 3306 and will default to that if this line is omitted
* **mysql\_ssh:** If the database server requires SSH connection, set this to true and provide addition information for the following parameters:
  * **mysql\_ssh\_username:** SSH user name used to connect to the server (probably different than the database user name)
  * **mysql\_ssh\_password:** Password associated with the SSH user

## Reports

There are 4 reports available. Each must be run separately via the command line. The provided commands must be run from the base directory (archivesspace\_top\_container\_reports). The generated reports are HTML files that will be saved to the reports/ directory.

### Barcode conflicts

Reports on top containers within the same resource or accession that have the same type and indicator values but different barcodes

To run:

`ruby barcode_conflicts.rb`

The report is organized by resource or accession, then by top container, then by barcodes associated with that top container, with links to each record where the association exists.

### Duplicate barcodes

Reports on barcodes that are duplicated in multiple top containers.

To run:

`ruby duplicate_barcodes.rb`

The report is organized by barcode value, then by resource/accession, then by top containers within the resource/accession, with links to records associated with the container.

### Location conflicts

Reports on top containers within the same resource/accession that have the same indicator and type but different locations.

To run:

`ruby location_conflicts.rb`

The report is organized by resource/accession, then by top container, then by location, followed by links to records where the container/location association exists.

### Missing locations

This one is actually a specialized version of the 'Location conflicts' report, but shows otherwise identical top containers in the same resource (by type and indicator) where some instances have an associated location and some do not.

To run:

`ruby missing_locations.rb`

The report is organized the same as the 'Location conflicts' report, but missing locations are listed as \[ NULL \]
