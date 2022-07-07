# !/bin/sh

wd=/disk/preprocessing/prepro_0127
cfg=$wd/cfg
config=$cfg/prepro.cfg
src=$wd/src

# load functions / config from other files
source $config &>/dev/null
if [ $? -eq 1 ]; then
	echo " The config file 'prepro.cfg' is not loaded properly. Check if the file is in the correct directory as assigned in 'run_preprocessing.sh' " >> ${prepro_log}
fi

source $src/db_functions.sh &>/dev/null
if [ $? -eq 1 ]; then
	echo " 'db_functions.sh' is not loaded properly. Check if the file exits" >> ${prepro_log}
fi

source $src/wf_functions.sh &>/dev/null
if [ $? -eq 1 ]; then
	echo " 'wf_functions.sh' is not loaded properly. Check if the file exits." >> ${prepro_log}
fi

source $src/wf_types.sh &>/dev/null
if [ $? -eq 1 ]; then
	echo " $src/wf_types.sh 'wf_types.sh' is not loaded properly. Check if the file exits." >> ${prepro_log}
fi
echo "files are sourced." >> ${prepro_log}

#########################################################################################
# z=.gz --> run wf_from_warc()
# t=.source--> run wf_from_langSepa()
#########################################################################################
run_prepro_job()
	{
		if [ "$( echo ${infile: -2} )" == "gz" ]; then 
			echo "$infile ==> run wf_from_warc ..." >> ${prepro_log}
			date >> ${prepro_log}
			wf_from_warc ${current_file_source} $infile 
		elif [ "$( echo ${infile: -6} )" == "source" ]; then			
			echo "$infile ==> run wf_from_langSepa ..." >> ${prepro_log}
			date >> ${prepro_log}
			wf_from_langSepa ${current_file_source} $infile
		else
			echo "Input file error: unknown file type " >> ${prepro_log}
		fi
	}

current_file_source=$1  
echo "Folder: ${current_file_source}" >> ${prepro_log}
infile=$2
#### check if infile has been preprocessed before ####
warc_done=($(mysql -D $db -h $dbServer -u$username -p$pass -se "SELECT count(*) FROM (SELECT id FROM warc WHERE file='${infile}') sid ;" ))
#### check if langSepa has been preprocessed properly ####
langSepa_status=($(mysql -D $db -h $dbServer -u$username -p$pass -se "SELECT langSepa FROM warc WHERE file='${infile}';"))
if [[ ${warc_done} == "1" ]] && [[ ${langSepa_status} == "finished" ]]; then
	echo "$infile has already been preprocessed successfully, REMOVE from ${current_file_source}" >> ${prepro_log}
	echo ` rm ${current_file_source}/${infile} `;
elif [[ "${warc_done}" == "1" ]] && [[ ${langSepa_status} == "NULL" ]]; then
	echo "$infile has already been preprocessed but NOT successfully, REMOVE previous database entry and RESTART job" >> ${prepro_log}
	db_remove_warc_entry
	run_prepro_job
elif [[ "${warc_done}" == "1" ]] && [[ ${langSepa_status} == "error" ]]; then
	echo "$infile has already been preprocessed but NOT successfully, REMOVE previous database entry and RESTART job" >> ${prepro_log}
	db_remove_warc_entry
	run_prepro_job
else
	echo "$infile has never been preprocessed, RUN ... " >> ${prepro_log}
	run_prepro_job
fi 


