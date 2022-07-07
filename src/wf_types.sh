# ./bin/sh

wf_from_warc()
{
	current_folder=$1
	infile=$2
	basename=$(echo ${infile} | sed 's/\(.*\)\..*/\1/' | sed 's/\(.*\)\..*/\1/')

	# log start time
	echo "wf_from_warc starts..." >> $log
	date >> $log
	date1=$(date -u +"%s")

	# insert job and warc in database
	current_job="$( get_job_name $basename )" #us_web_2015
	db_insert_job 
	job_id="$(db_get_job_id)"
	db_insert_warc # includig copy='running'
	warc_id="$(db_get_warc_id)" 

	# create wf folders for each warc/source input file for running preprocessing
	create_wf_folder $run_dir $basename

	#####  copy_in #######	
	db_update_copy_in_running
  echo `cp ${current_folder}/${infile} ${f1_warc_gz_dir} `;
  # check size of copied file, if same as orginal, delete file in source folder
	original_file=${current_folder}/${infile} 
	copied_file=${f1_warc_gz_dir}/${infile}
	original_size=`du -s ${copied_file} | cut -f1 `;
	if [ "$( check_file_size ${original_file} ${copied_file} )" == "s" ]; then
		echo "$original_file - copy correct. Remove orginal file in $current_folder " >> $log
		echo `rm -f ${original_file} `;
		db_update_copy_in_finished
	else
		echo "error with copy file from source folder " >> $log
		date >> $log
		db_update_copy_in_error
		break
	fi
	
	#####  warcEx #######
	db_update_warcEx_running
	process_warc ${infile}
	output_warc=`du -s ${f3_langSepa_dir}/${basename}.warc.source | cut -f1 `;
	if [ "${output_warc}" -gt 1000 ]; then
		echo "finish warc extraction " >> $log
		date >> $log
		db_update_warcEx_finished
	else
		echo "error with warc extraction" >> $log
		date >> $log
		db_update_warcEx_error
		break
	fi

	#####  langSepa #######
	db_update_langSepa_running
	process_langSepa ${basename}
	output_langSepa=`du -s ${f3_langSepa_dir}/LangSepa-output/ | cut -f1 `;
	if [ "${output_langSepa}" -gt 1000 ]; then
		echo "finish langSepa " >> $log
		date >> $jog
		db_update_langSepa_finished
	else
		echo "error with langSepa" >> $log
		date >> $log
		db_update_langSepa_error
		break
	fi

	#####  outSelect #######
	db_update_outSelect_running
	select_output ${basename}
	output_Select=`du -s ${f4_selected_output} | cut -f1 `;
	if [ "${output_Select}" -gt 10 ]; then
		echo "finish outSelect " >> $log
		date >> $log
		db_update_outSelect_finished
	else
		echo "error with outSelect" >> $log
		date >> $log
		db_update_outSelect_error
		break
	fi

	#####  copy_out #######
	cd ${f4_selected_output}
	output_gz_file=$(find `pwd` -name "*.gz") # absolute path
	echo ` cp ${output_gz_file} ${destination} `
	cd $wd
	echo "output_gz_file = ${output_gz_file}" >> $log
	echo "destination = ${destination}" >> $log
	output_gz_file_basename=` basename ${output_gz_file} `;
	selected_file_destination=${destination}/${output_gz_file_basename}
	echo "selected_file_destination = ${selected_file_destination}" >> $log
	if [[ $(diff ${output_gz_file} ${selected_file_destination}) ]]; then # if diff, there is output. output sizes are very different!
		echo "error with copy file OUT to destination folder " >> $log
		date >> $log
		db_update_copy_out_error
	else
		echo "${selected_file_destination} - copy OUT correct. " >> $log
		echo "copy_out finished" >> $log
		date >> $log
		db_update_copy_out_finished
	
		#####  summarise job stats and remove job folders #######
		# total time used
		date2=$(date -u +"%s")
		diff=$((date2 - date1))
		echo " wf_from_langSepa took $(($diff / 60)) minutes and $(($diff % 60)) seconds " >> $log
		# input and output size comparison
		selected_gz_size=` du -s ${selected_file_destination} | cut -f1 `;
		z=$(echo "scale=2; ${original_size}/${selected_gz_size}" | bc)
		echo " file size .source: ${original_size} output.gz: ${selected_gz_size} = reduced by $z times"  >> $log
		echo "wf_from_langSepa finished ..." >> $log
		# move log to FINISHED_JOB_LOG
		echo ` mv $log ${finished_job_log} `
		## delete current preprocessing job folder ##
	  rm -r $run_dir/${basename}
	fi
}

wf_from_langSepa()
{
	echo "in wf_from_langSepa"
	current_folder=$1  #/disk/preprocessing/test_prepro/source_prepro/folder1
	infile=$2 # us_web_2015.00001.warc.source
	basename=$(echo ${infile} | sed 's/\(.*\)\..*/\1/' | sed 's/\(.*\)\..*/\1/') # us_web_2015.00001

	# log start time
	echo "wf_from_langSepa starts..." >> $log
	date >> $log
	date1=$(date -u +"%s")

	# insert job and insert warc
	current_job="$( get_job_name $basename )" #us_web_2015
	db_insert_job 
	job_id="$(db_get_job_id)"
	db_insert_warc # includig copy='running'
	warc_id="$(db_get_warc_id)" 

	# create wf folders for each warc/source input file for running preprocessing
	create_wf_folder $run_dir $basename

	#####  copy_in #######
	db_update_copy_in_running
	echo `cp ${current_folder}/${infile} ${f3_langSepa_dir} `;

	# check size of copied file, if same as orginal, delete file in source folder
	original_file=${current_folder}/${infile} 
	copied_file=${f3_langSepa_dir}/${infile}
	original_size=`du -s ${copied_file} | cut -f1 `;
	if [ "$( check_file_size ${original_file} ${copied_file} )" == "s" ]; then
		echo "$original_file - copy correct. Remove orginal file in $current_folder " >> $log
		echo `rm -f ${original_file} `;
		db_update_copy_in_finished
	else
		echo "error with copy file from source folder " >> $log
		date >> $log
		db_update_copy_in_error
		break
	fi

	######  langSepa #######
	db_update_langSepa_running
	process_langSepa ${basename}
	output_langSepa=`du -s ${f3_langSepa_dir}/LangSepa-output/ | cut -f1 `;
	if [ "${output_langSepa}" -gt 100 ]; then
		echo "finish langSepa " >> $log
		date >> $log
		db_update_langSepa_finished
	else
		echo "error with langSepa" >> $log
		date >> $log
		db_update_langSepa_error
		break
	fi

	#####  outSelect #######
	db_update_outSelect_running
	select_output ${basename}
	output_Select=`du -s ${f4_selected_output} | cut -f1 `;
	if [ "${output_Select}" -gt 10 ]; then
		echo "finish outSelect " >> $log
		date >> $log
		db_update_outSelect_finished
	else
		echo "error with outSelect" >> $log
		date >> $log
		db_update_outSelect_error
		break
	fi

	#####  copy_out #######
	cd ${f4_selected_output}
	output_gz_file=$(find `pwd` -name "*.gz") # absolute path
	echo ` cp ${output_gz_file} ${destination} `
	cd $wd
	echo "output_gz_file = ${output_gz_file}" >> $log
	echo "destination = ${destination}" >> $log
	output_gz_file_basename=` basename ${output_gz_file} `;
	selected_file_destination=${destination}/${output_gz_file_basename}
	echo "selected_file_destination = ${selected_file_destination}" >> $log
	if [[ $(diff ${output_gz_file} ${selected_file_destination}) ]]; then # if diff, there is output. output sizes are very different!
		echo "error with copy file OUT to destination folder " >> $log
		date >> $log
		db_update_copy_out_error
	else
		echo "${selected_file_destination} - copy OUT correct. " >> $log
		echo "copy_out finished" >> $log
		date >> $log
		db_update_copy_out_finished
	
		#####  summarise job stats and remove job folders #######
		# total time used
		date2=$(date -u +"%s")
		diff=$((date2 - date1))
		echo " wf_from_langSepa took $(($diff / 60)) minutes and $(($diff % 60)) seconds " >> $log
		# input and output size comparison
		selected_gz_size=` du -s ${selected_file_destination} | cut -f1 `;
		z=$(echo "scale=2; ${original_size}/${selected_gz_size}" | bc)
		echo " file size .source: ${original_size} output.gz: ${selected_gz_size} = reduced by $z times"  >> $log
		echo "wf_from_langSepa finished ..." >> $log
		# move log to FINISHED_JOB_LOG
		echo ` mv $log ${finished_job_log} `
		## delete current preprocessing job folder ##
	  rm -r $run_dir/${basename}
	fi
}