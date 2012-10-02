#!/bin/bash
#
# MySQL backup script
# 

#===========================================
# Config vars
#===========================================

# MySQL login
DBUSER=__MYSQL_USERNAME__

# MySQL password
DBPASS=__MYSQL_PASSWORD__

# MySQL host
DBHOST=__MYSQL_HOST__

# List of databases not to backup
EXCLUDE_DB=""

# List of tables not to backup
# example: "db1.table1 db1.table2 db2.table1"
EXCLUDE_TABLE=""

# list of emails of people receiving the notification
EMAILS="__EMAIL_ADDRESS__"

# notification email subject
EMAIL_SUBJECT="__EMAIL_SUBJECT__"


#===========================================
#  Advanced configuration
#===========================================

PATH=/bin:/usr/bin:/home/mysql/bin; export PATH
DATE=`date +%Y-%m-%d`

# number of days we'll keep the backup
DAYS_TO_KEEP=20
OLD_DATE=`date +"%Y-%m-%d" --date "$DAYS_TO_KEEP days ago"`
TIMESTAMP_1=`date +%s`

BACKUP_PARENT_DIR=__PATH_TO_MYSQL_BACKUP_DIR__

BACKUP_DIR="$BACKUP_PARENT_DIR/$DATE"

OLD_BACKUP_DIR="$BACKUP_PARENT_DIR/$OLD_DATE"

OPTIONS="--allow-keywords --quick --force --extended-insert"

COUNTER=0

# this var contains the text to be emailed
MAIL_TEXT=""


#==========================================
# useful functions
#==========================================
# Returns the list of DB tables for the given database
get_tables ()
{
        TABLES="`mysql --user=$DBUSER --password=$DBPASS --host=$DBHOST --batch --skip-column-names --database=$1 -e "show tables"`"
}

# Returns the list of db tables to exclude for the given database
get_excl_tables ()
{
        for table in $EXCLUDE_TABLE
        do
                POSITION=`expr index "$table" "."`
                local DB=${table:0:`expr $POSITION - 1`}
                if [ "$DB" == "$1" ]
                then
                        local FIN=${table:`expr $POSITION`}
                        TABLES_EXCL="$TABLES_EXCL $FIN"
                fi
        done
}


# Start backup
MAIL_TEXT="$MAIL_TEXT\nBackup job started at `date +"%H:%M:%S"`\n"

# Also start writing in the log file
echo
echo "START **************************************"
echo "$DATE Backup"
echo

# eventually create backup directory
mkdir -p $BACKUP_DIR

# fetch the list of databases to backup
DBNAMES="`mysql --user=$DBUSER --password=$DBPASS --host=$DBHOST --batch --skip-column-names -e "show databases"`"

# exclude unwanted databases
for exclude in $EXCLUDE_DB
do
        DBNAMES=`echo $DBNAMES | sed "s/\b$exclude\b//g"`
done


# loop on databases
for db in $DBNAMES
do
        MAIL_TEXT="$MAIL_TEXT\ndumping database $db..."
        get_tables $db
        echo "*** database: $db ***"
        mkdir -p "$BACKUP_DIR/$db"
		# the list of tables for this databse is now in $TABLES

        # exclude unwanted tables for this database
        get_excl_tables $db
        for exclude in $TABLES_EXCL
        do
                TABLES=`echo $TABLES | sed "s/\b$exclude\b//g"`
        done
        for table in $TABLES
        do
                echo "dumping table: $table"
                DUMP_FILE="$BACKUP_DIR/$db/$table.sql"
                mysqldump --user=$DBUSER --password=$DBPASS --host=$DBHOST $OPTIONS $db $table > $DUMP_FILE
                gzip $DUMP_FILE
                COUNTER=`expr $COUNTER + 1`
        done
done


# create link to daily backup
rm -f "$BACKUP_PARENT_DIR/current"
ln -s $BACKUP_DIR "$BACKUP_PARENT_DIR/current"


# remove oldest backup
if [ -e "$OLD_BACKUP_DIR" ]
then
        echo
        OLD_BACKUP_DIR_DU=`du -sh $OLD_BACKUP_DIR`
        echo "deleting old backup dir $OLD_BACKUP_DIR_DU"
        MAIL_TEXT="$MAIL_TEXT\ndeleting old backup dir $OLD_BACKUP_DIR_DU\n"
        rm -rf $OLD_BACKUP_DIR
else
        echo
        echo "no old backup dir to delete"
        MAIL_TEXT="$MAIL_TEXT\nno old backup dir to delete\n"
fi

# calculate how long it took
TIMESTAMP_2=`date +%s`
EXECUTION_TIME=`expr $TIMESTAMP_2 - $TIMESTAMP_1`
echo
echo "$COUNTER tables saved in $EXECUTION_TIME seconds"
MAIL_TEXT="$MAIL_TEXT\n$COUNTER tables saved in $EXECUTION_TIME seconds\n"

# calculate backup size
BACKUP_DIR_DU=`du -sh $BACKUP_DIR`
echo "Backup dir size: $BACKUP_DIR_DU"
MAIL_TEXT="$MAIL_TEXT\nBackup dir size : $BACKUP_DIR_DU\n"

# end
echo
echo "FIN **************************************"
MAIL_TEXT="$MAIL_TEXT\nBackup job ended at `date +"%H:%M:%S"`"


# finally send notification email
for email in $EMAILS
do
       echo -e $MAIL_TEXT | mail -s $EMAIL_SUBJECT $email
done