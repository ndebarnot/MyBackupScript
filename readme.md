MySQL backup shell script

This script should be called daily via cron and will backup all your MySQL databases in separate gziped
files (one directory per database and one file per table) in a specific directory on the server. Can be
called remotely if able to connect to the MySQL server.

This script will also store daily backups in separate directories and automatically rotate the folders.