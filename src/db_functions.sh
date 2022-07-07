# ./bin/bash

##########################################
#	operations for database
##########################################
compare_list()
{
	out=$1
	string_to_compare=$2
	cnt=${#out[@]}
	cnty=0
	for (( i=0 ; i<${cnt} ; i++ )); do
		if [ "${out[$i]}" == "${string_to_compare}" ]; then
			((cnty++))
		else
			continue
		fi
	done
	if [ $cnty -gt 0 ]; then
		echo $cnty
		echo "y"
	else
		echo "n"
	fi
}

db_remove_warc_entry()
{
	echo ` mysql -D $db -h $dbServer -u$username -p$pass -se  "DELETE FROM warc WHERE file='${infile}';" `
}

db_get_job_id()
{
	echo ` mysql -D $db -h $dbServer -u$username -p$pass -se  "SELECT id FROM job WHERE job_name='${current_job}';" ` 
}

db_get_warc_id()
{
	echo ` mysql -D $db -h $dbServer -u$username -p$pass -se "SELECT id FROM warc WHERE file='${infile}';" `
}

db_insert_job()
{
	out=($(mysql -D $db -h $dbServer -u$username -p$pass -se "SELECT job_name FROM job;"))
	if [[ -z "$out" ]] || [[ "$( compare_list $out ${current_job} )" == "n" ]] ; then # if empty or job not in job-table
		# TODO: get API info to update start, finish, status_crawl
		echo ` mysql -D $db -h $dbServer -u$username -p$pass -se "INSERT INTO job (job_name,folder_name,status_prepro) VALUES ('$current_job','$current_job', 'running');" `
	else
		continue
	fi
}

db_insert_warc()
{
	dateOfUse=$(TZ=CEST date +'%F %T')
	echo ` mysql -D $db -h $dbServer -u$username -p$pass -se "INSERT INTO warc (job_id,file,last_changed, server) VALUES ('$job_id', '${infile}', '$dateOfUse','${server}');" `
}

db_update_copy_in_running()
{
	dateOfUse=$(TZ=CEST date +'%F %T')
	echo ` mysql -D $db -h $dbServer -u$username -p$pass -se "UPDATE warc SET copy_in='running', last_changed='$dateOfUse' WHERE id='$warc_id';" `
}

db_update_copy_in_finished()
{
	dateOfUse=$(TZ=CEST date +'%F %T')
	echo ` mysql -D $db -h $dbServer -u$username -p$pass -se "UPDATE warc SET copy_in='finished', last_changed='$dateOfUse' WHERE id='$warc_id';" `
}

db_update_copy_in_error()
{
	dateOfUse=$(TZ=CEST date +'%F %T')
	echo ` mysql -D $db -h $dbServer -u$username -p$pass -se "UPDATE warc SET copy_in='error', last_changed='$dateOfUse' WHERE id='$warc_id';" `
}

db_update_warcEx_running()
{
	dateOfUse=$(TZ=CEST date +'%F %T')
	echo ` mysql -D $db -h $dbServer -u$username -p$pass -se "UPDATE warc SET warcEx='running', last_changed='$dateOfUse' WHERE id='$warc_id';" `
}

db_update_warcEx_finished()
{
	dateOfUse=$(TZ=CEST date +'%F %T')
	echo ` mysql -D $db -h $dbServer -u$username -p$pass -se "UPDATE warc SET warcEx='finished', last_changed='$dateOfUse' WHERE id='$warc_id';" `
}

db_update_warcEx_error()
{
	dateOfUse=$(TZ=CEST date +'%F %T')
	echo ` mysql -D $db -h $dbServer -u$username -p$pass -se "UPDATE warc SET warcEx='error', last_changed='$dateOfUse' WHERE id='$warc_id';" `
}

db_update_langSepa_running()
{
	dateOfUse=$(TZ=CEST date +'%F %T')
	echo ` mysql -D $db -h $dbServer -u$username -p$pass -se "UPDATE warc SET langSepa='running', last_changed='$dateOfUse' WHERE id='$warc_id';" `
}

db_update_langSepa_finished()
{
	dateOfUse=$(TZ=CEST date +'%F %T')
	echo ` mysql -D $db -h $dbServer -u$username -p$pass -se "UPDATE warc SET langSepa='finished', last_changed='$dateOfUse' WHERE id='$warc_id';" `
}

db_update_langSepa_error()
{
	dateOfUse=$(TZ=CEST date +'%F %T')
	echo ` mysql -D $db -h $dbServer -u$username -p$pass -se "UPDATE warc SET langSepa='error', last_changed='$dateOfUse' WHERE id='$warc_id';" `
}

db_update_outSelect_running()
{
	dateOfUse=$(TZ=CEST date +'%F %T')
	echo ` mysql -D $db -h $dbServer -u$username -p$pass -se "UPDATE warc SET outSelect='running', last_changed='$dateOfUse' WHERE id='$warc_id';" `
}

db_update_outSelect_error()
{
	dateOfUse=$(TZ=CEST date +'%F %T')
	echo ` mysql -D $db -h $dbServer -u$username -p$pass -se "UPDATE warc SET outSelect='error', last_changed='$dateOfUse' WHERE id='$warc_id';" `
}

db_update_outSelect_finished()
{
	dateOfUse=$(TZ=CEST date +'%F %T')
	echo ` mysql -D $db -h $dbServer -u$username -p$pass -se "UPDATE warc SET outSelect='finished', last_changed='$dateOfUse' WHERE id='$warc_id';" `
}

db_update_copy_out_finished()
{
	dateOfUse=$(TZ=CEST date +'%F %T')
	echo ` mysql -D $db -h $dbServer -u$username -p$pass -se "UPDATE warc SET copy_out='finished', last_changed='$dateOfUse' WHERE id='$warc_id';" `
}

db_update_copy_out_error()
{
	dateOfUse=$(TZ=CEST date +'%F %T')
	echo ` mysql -D $db -h $dbServer -u$username -p$pass -se "UPDATE warc SET copy_out='error', last_changed='$dateOfUse' WHERE id='$warc_id';" `
}