# !/bin/sh

# to run use: nohup sh src/run_preprocessing.sh WORKING_DIRECTORY(absolute dir) &
wd=$1
cfg=$wd/cfg
config=$cfg/prepro.cfg
src=$wd/src

# load functions / config from other files
source $config &>/dev/null
if [ $? -eq 1 ]; then
	echo " The config file 'prepro.cfg' is not loaded properly. Check if the file is in the correct directory as assigned in 'run_preprocessing.sh' " >> ${prepro_log}
fi

source $piority &>/dev/null
if [ $? -eq 1 ]; then
	echo " The piority file $piority is not loaded properly. Check if the file is in the correct directory as assigned in 'prepro.cfg' " >> ${prepro_log}
fi

############################################################
#	find oldest "inactive" file (not been changed in last 1 minute)
# function: find_oldest_file
# input: a directory
# output: filename of the oldest file in the folder
############################################################
find_oldest_file()
	{
		dir=$1
		cd $dir
		if [ -n "$(find . -maxdepth 1 -name "*.gz" -o -name "*.source"  -type f -mmin +1)" ]; then # -n checks whether the string is not null
			oldest_file=`ls -t | tail -n 1`; 
		else
			oldest_file=""
			continue		
		fi	
		cd $wd
		echo "${oldest_file}"
	}

#############################################################################
# function: get_file_source_folder_list_size
# input: directory of file_source (where the .source / .warc.gz are)
# output: list of directories in file_source, sorted by size (smallest first)
#############################################################################
get_file_source_folder_list_size()
	{
		dir=$1
		cd $dir
		if [ $( find . -maxdepth 1 -type d | wc -l ) -gt 0  ]; then # if there are folders
			piority_list=`find . -maxdepth 1 -type d -exec du -s {} \; | sort -n | cut -f2 | xargs -n 1 basename` ;
			echo "file_source_folder_list_tmp" > ${file_source_folder_list_tmp} 
			echo "${piority_list}" >> ${file_source_folder_list_tmp} 
			echo ` sed -i '$ d' ${file_source_folder_list_tmp} ` # remove . from last line
		else
			piority_list=""
			continue		
		fi	
		remove_wrong_prefix_folder ${file_source_folder_list_tmp}
		rm ${file_source_folder_list_tmp} 
		rm ${removed_list}
		cd $wd
	}

##################################################################
# function: get_file_source_folder_list_age
# input: directory of file_source (where the .source / .warc.gz are)
# output: list of directories in file_source, sorted by age (oldest first)
# parameter: $1 ${file_source}
##################################################################
get_file_source_folder_list_age()
	{
		dir=$1
		cd $dir
		if [ $( find . -maxdepth 1 -type d | wc -l ) -gt 0  ]; then # if there are folders
			## oldest folder first
			list1=`ls -cdr -- */ | cut -d'/' -f1`
		else
			list1=""
			continue		
		fi	
		echo "${list1}" > ${file_source_folder_list_tmp} 
		remove_wrong_prefix_folder ${file_source_folder_list_tmp}
		rm ${file_source_folder_list_tmp} 
		rm ${removed_list}
		cd $wd
	}

##################################################
#	function: remove_wrong_prefix_folder
# subfunction of get_file_source_folder_list_*()
# only keep folder names with prefix of 2 or 3 chars
# parameter: $1 filename
###################################################
remove_wrong_prefix_folder()
	{
		inList=$1
		IFS=$'\n' list1=($(cat ${inList}))
		cnt=${#list1[@]}
		#remove folder names having prefix not with 2 or 3 charactors
		for (( i=0 ; i<${cnt} ; i++ )); do # position 0: header
			if [ "$( echo "${list1[i]}" | cut -c 3 )" == "_" ]; then 
				echo ${list1[i]} >> ${file_source_folder_list}
			elif [ "$( echo "${list1[i]}" | cut -c 4 )" == "_" ]; then
				echo ${list1[i]} >> ${file_source_folder_list}
			else
				echo ${list1[i]} >> ${removed_list}
			fi
		done
	}

############################################
# run GNU parallel jobs
############################################

# get folder list from ${file_source}, start from oldest folder 
rm ${file_source_folder_list}
rm ${folder_list}
get_file_source_folder_list_age ${file_source} # output in: ${file_source_folder_list}

# combine ${file_source_folder_list} and ${piority_folder_list} into ${folder_list}
cat ${piority} > ${folder_list_ini}
echo " " >> ${folder_list_ini}
cat ${file_source_folder_list} >> ${folder_list_ini}

# read in folder_list
IFS=$'\n' folder_list=($(cat ${folder_list_ini}))
cnt=${#folder_list[@]}

# get piority_folder list (use when only want to deal with files in piority_folder.ini )
# IFS=$'\n' folder_list=($(cat $piority))
# cnt=${#folder_list[@]}

## TODO: run on multiple servers using parallel
## parallel --sshloginfile hosts.txt echo "Number {}: Running on \`hostname\`" ::: 1 2 3 4
for (( i=1 ; i<${cnt} ; i++ )); do # position 0: header
	current_file_source=${file_source}/${folder_list[i]}
	echo "current_file_source=${current_file_source}"  
	infile=$( find_oldest_file ${current_file_source} )
	echo "infile first = $infile"
	if [ "$( echo ${infile: -2} )" == "gz" ]; then 
		parallel --gnu --verbose --delay $delayWarc -j$maxWarcExt  sh ${preprocessing_main} ${current_file_source} {} ::: ` find ${current_file_source} -maxdepth 1 -name "*.gz"  -type f -mmin +1 -printf "%f\n" `
	elif [ "$( echo ${infile: -6} )" == "source" ]; then
		parallel --gnu --verbose --delay $delayLangSepa -j$maxLangSepa sh ${preprocessing_main} ${current_file_source} {} :::  ` find ${current_file_source} -maxdepth 1 -name "*.source"  -type f -mmin +1 -printf "%f\n" `
	fi
done

