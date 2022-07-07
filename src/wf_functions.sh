# ./bin/sh

########################################################################################
#	create subfolder $wf under $wd so that each input warc.gz or warc.source has its own worflow folder
# input: file name .warc.source or .war.gz
#########################################################################################
create_wf_folder()
	{
		run_dir=$1
		basename=$2 		
		wf=${run_dir}/$basename
		mkdir $wf

		mkdir $wf/f1_warc_gz_dir
		mkdir $wf/f2_warcExtractor_dir
		mkdir $wf/f3_langSepa_dir
		mkdir $wf/f4_selected_output

		# set path for each subfolder
		log=$wf/${basename}.log

		f1_warc_gz_dir=$wf/f1_warc_gz_dir
		f2_warcExtractor_dir=$wf/f2_warcExtractor_dir
		f3_langSepa_dir=$wf/f3_langSepa_dir
		f4_selected_output=$wf/f4_selected_output

		# copy jar and ini files to $wf
		cp $warcEx $wf/
		cp $langSepa $f3_langSepa_dir/
		cp ${langSepa_ini1} $f3_langSepa_dir/
		cp ${langSepa_ini2} $f3_langSepa_dir/
		cp ${tld_list} $wf/
		cp ${stopwort_list} $wf/
		cp ${uni_trigramm_list} $wf/
		cp ${stopwort_uni_trigramm_list} $wf/

		stopwort_list_local=$wf/stopwort_list.ini
		tld_list_local=$wf/TLD_commonlang.txt
		uni_trigramm_list_local=$wf/uni_trigramm_list.ini

		# combine stopwort und uni_trigramm_list
		cat ${stopwort_list} > ${stopwort_uni_trigramm_list}
		echo " " >> ${stopwort_uni_trigramm_list}
		tail -n +2 -q ${uni_trigramm_list} >> ${stopwort_uni_trigramm_list}

		stopwort_uni_trigramm_list_local=$wf/stopwort_uni_trigramm_list.ini
	}

#########################################################################################
#	check if two files have the same size
# input: two files
# output: 's' same, 'd' different
#########################################################################################
check_file_size()
	{
		file1="$(du -k $1 | cut -f1)"
		file2="$(du -k $2 | cut -f1)"
		# echo "original file size = $file1" >> ${prepro_log}
		# echo "copied file size = $file2, diff = $(($file1-$file2))" >> ${prepro_log}
		if [ $(($file1-$file2)) -le 10000 ]; then  # exact size might be different, so some tolerance
			echo "s"
		else
			echo "d"
		fi
	}

############################################################
#	unzip and run warc_extractor
# input: .warc.gz file | $f1_warc_gz_dir/$warc_gz_filename
# output: .warc.source file | ${3_langSepa_dir}/$basename
############################################################
process_warc()
	{
		warc_gz_filename=$1
		warc_filename=$(echo $warc_gz_filename | sed 's/\(.*\)\..*/\1/') #remove extension ".gz"
		
		########	unzip warc.gz files  ########
		# input: .warc.gz file | $f1_warc_gz_dir/$warc_gz_filename
		# output: .warc file   | ${f2_warcExtractor_dir}/$warc_filename

		if [ -f ${f2_warcExtractor_dir}/${warc_filename} ]; then
			echo "File ${f2_warcExtractor_dir}/$warc_filename exists. Skip this one." >> $log
		continue
		fi
		echo "start unzip $warc_filename " >> $log
		date >> $log
		gunzip -c ${f1_warc_gz_dir}/${warc_gz_filename} > ${f2_warcExtractor_dir}/${warc_filename}
		echo "finish upzip $warc_filename " >> $log
		date >> $log

	#########	run warc_extractor [tools.jWarcEx-0.0.1-SNAPSHOT.jar] ########
	# input: .warc file   		 | ${2_warcExtractor_dir}/$warc_filename
	# output: .warc.source file | ${3_langSepa_dir}/$basename

		basename=$(echo $warc_filename | sed 's/\(.*\)\..*/\1/') #remove extension ".warc"
		source_filename=${basename}.warc.source
		if [ -f ${f2_warcExtractor_dir}/${warc_filename} ]; then
			echo "start warc extraction " >> $log
			date >> $log
			java -Xmx2G -jar $wf/tools.jWarcEx-0.0.1-SNAPSHOT.jar ${f2_warcExtractor_dir}/${warc_filename} ${f3_langSepa_dir}/${source_filename} 6
		else
			echo "File $warc_filename does not exists in f2_warcExtractor_dir " >> $log
			db_update_warcEx_error
			date >> $log
		fi
}

#########################################################################################
#	run langSepa [LangSepa.jar]
# input:  .warc.source file | ${f3_langSepa_dir}/$basename
#					-- [LangSepa.ini] : parameter tunning for LangSepa.jar !!! NO PREFIX should be set!!!
#					-- [db-sources.ini] : to define source of word list for each langauge (optional)
# output: .txt files in 3 subfolders : LangSepa-output/Stopwort ../Trigramm ../Unigramm
#########################################################################################
process_langSepa()
	{
		basename=$1
		echo "start langSepa " >> $log
		date >> $log
		# LangSepa.jar must be triggered in the same directory!!
		# input file muss end with "txt"
		cd ${f3_langSepa_dir}
		mv ${basename}.warc.source ${basename}.source.txt
		java -Xmx2G -jar LangSepa.jar 
		cd $wf
	}

################################################
#	get prefix (until first '-') of a file name
# parameter: $1 filename
#################################################
get_prefix()
	{
		if [ "$( echo "$1" | cut -c 3 )" == "_" ]; then 
			prefix="$( echo "$1" | cut -c 1-2 )" #tld
			echo $prefix
		else
			prefix="$( echo "$1" | cut -c 1-3 )" #lang
			echo $prefix
		fi
	}

################################################
#	get job name (until first '-') of a file name
# parameter: $1 filename
#################################################
get_job_name()
	{
		if [ "$( echo "$1" | cut -c 3 )" == "_" ]; then 
			job_name="$( echo "$1" | cut -c 1-11 )" #tld
			echo $job_name
		else
			job_name="$( echo "$1" | cut -c 1-13 )" #lang
			echo $job_name
		fi
	}

################################################
#	compare lang with list
# parameter: $1: prefix (lang) $2: list
# NOTE: list file shall contain a heading for parsing
#################################################
compare_lang_list()
	{
		lang_to_check=$1
		list=$2
		IFS=$'\n' a=($(cat $list))
		cnt=${#a[*]}
		for (( i=0 ; i<${cnt} ; i++ )); do
			if [ "${a[$i]}" == ${lang_to_check} ]; then
				echo "y"
			else
				continue
			fi
		done
	}

##########################################################
#	compare TLD with lists
# if TLD in the list -> save the languages of the found tld in array $lang
# parameter: $1: tld $2: list
# NOTE: list file shall contain a heading for parsing
###########################################################
get_tld_langs()
	{
		tld_to_check=$1
		list=$2
		IFS=$'\n' a=($(cat $list))
		a=${#a[*]}
		b=1
		length_a=$(($a - $b))
		for i in $(seq ${length_a}); do
			tld=("$( echo ${a[i]} | cut -c 1-2 )"); # outer () append element, otherwise, string 
			if [ $tld == ${tld_to_check} ]; then
				lang+=("$( echo ${a[i]} | cut -c 4-6 )");
			else 
				continue
			fi
		done
	}

######################################################################
#	keep and archive only the ${lang_to_check}0000.txt in LangSepa-output
# keep output in Stopwort-folder
#######################################################################
keep_stopwort()
{
	lang_to_check=$1
	basename=$2
	echo "keep STOPWORT output file - ${lang_to_check}0000.txt " >> $log
	# move stopwort result to f4 and change name of the file using basename
	echo `mv ${f3_langSepa_dir}/LangSepa-output/Stopwort/${lang_to_check}0000.txt ${f4_selected_output}/${basename}_${lang_to_check}_stopwort.txt`;
}

######################################################################
#	keep and archive only the ${lang_to_check}0000.txt in LangSepa-output
# keep both outputs in Trigramm- AND Unigramm-folders
#######################################################################
keep_unitrigramm()
{
	lang_to_check=$1
	basename=$2
	echo "keep TRIGRAMM/UNIGRAMM output files - ${lang_to_check}0000.txt " >> $log
	# move stopwort result to f4 and change name of the file using basename
	echo `mv ${f3_langSepa_dir}/LangSepa-output/Trigramm/${lang_to_check}0000.txt ${f4_selected_output}/${basename}_${lang_to_check}_tri.txt`;
	echo `mv ${f3_langSepa_dir}/LangSepa-output/Unigramm/${lang_to_check}0000.txt ${f4_selected_output}/${basename}_${lang_to_check}_uni.txt`;
}

#######################################################################################################
#	keep and archive all files in LangSepa-output
# echo `tar -zcf ${f4_selected_output}/${basename}.all.tar.gz ${f3_langSepa_dir}/LangSepa-output/ `;
# archive this way will keep the whole directory path, later difficult to re-locate
# solution: change folder name "LangSepa-output" into "$basename_LangSepa-output" to avoid later collision
# tar at local folder and send result to f4
########################################################################################################
keep_all()
{
	basename=$1
	echo "keep ALL output files"  >> $log
	# tar target-name dir-to-be-compressed
	echo `mv ${f3_langSepa_dir}/LangSepa-output/ ${f3_langSepa_dir}/${basename}_LangSepa-output`;
	cd ${f3_langSepa_dir}
	echo `tar -zcf ../f4_selected_output/${basename}.all.tar.gz ${basename}_LangSepa-output/ `;
	cd $wd
}

##########################################################################
# tar all outputs in /f4_selected_output into a BASENAME_selected.tar.gz
##########################################################################
tar_selected_outputs()
{
	cd ${f4_selected_output}
	# archieve all output files into one tar
	echo `tar -zcf ${basename}.selected.tar.gz *.txt`;
  cd $wd
}

#########################################################################################
#	select outputs of langSepa for language specific warc files (file name start with 3 chars)
# input: f3_langSepa_dir/LangSepa-output/
#########################################################################################
select_output_lang()
	{
		lang_to_check=$1
		basename=$2
		prefix="$( get_prefix $basename )"
		echo "output selected using LANGUAGE $prefix" >> $log
		# check if the lang is in stopwort list
		if [ "$( compare_lang_list ${lang_to_check} ${stopwort_list_local} )" == "y" ]; then
			# if yes, select lang0000.txt file in folder Stopwort
			echo "$prefix is on ${stopwort_list_local} list" >> $log
			keep_stopwort ${lang_to_check} $basename
			tar_selected_outputs
		elif [ "$( compare_lang_list ${lang_to_check} ${uni_trigramm_list_local} )" == "y" ]; then
			echo "$prefix is on ${uni_trigramm_list_local} list" >> $log
			keep_unitrigramm ${lang_to_check} $basename
			tar_selected_outputs
		else
			echo "$prefix is NOT on ${stopwort_list_local} or ${uni_trigramm_list_local} list" >> $log
			keep_all $basename
		fi
	}

#########################################################################################
#	select outputs of langSepa for TLD specific warc files (source file name start with 2 chars)
# input: f3_langSepa_dir/LangSepa-output/
#########################################################################################
select_output_tld()
{ 
	tld_to_check=$1 
	basename=$2
  lang=()
  get_tld_langs ${tld_to_check} ${tld_list_local}  # has to be run to obtain $lang
  l=${#lang[*]}

  tld_prefix="$( get_prefix $basename )"
	echo "output selected using TLD ${tld_prefix}" >> $log

	if [ $l -gt 0 ]; then # if $lang is not empty (tld exists)
		b=1
		length_lang=$(($l - $b))
		count=0
		for i in $(seq 0 ${length_lang}); do  # NOTE: array with index starting from 0
			# check if all languages of tld on stopwort_uni_trigramm_list.ini
			if [ "$( compare_lang_list ${lang[i]} ${stopwort_uni_trigramm_list_local} )" == "y" ]; then
				((count++))
				echo "${tld_prefix}:${lang[i]} is on stopwort_uni_trigramm_list.ini" >> $log
			else
				echo "${tld_prefix}:${lang[i]} is NOT on stopwort_uni_trigramm_list.ini" >> $log
			fi
		done

		if [ $count -eq ${#lang[*]} ]; then
			# if all languages of the tld are on stopwort_uni_trigramm_list.ini, keep BASENAME_LANG_stopwort.txt or BASENAME_LANG_uni.txt & BASENAME_LANG_tri.txt files
			for i in $(seq 0 ${length_lang}); do 
				echo "all languages of the TLD are on stopwort_uni_trigramm_list.ini" >> $log
				if [ "$( compare_lang_list ${lang[i]} ${stopwort_list_local} )" == "y" ]; then
					# if yes, select lang0000.txt file in folder Stopwort
					echo "$prefix is on ${stopwort_list_local} list" >> $log
					keep_stopwort ${lang_to_check} $basename
				elif [ "$( compare_lang_list ${lang[i]} ${uni_trigramm_list_local} )" == "y" ]; then
					echo "$prefix is on ${uni_trigramm_list_local} list" >> $log
					keep_unitrigramm ${lang_to_check} $basename
				fi
				tar_selected_outputs
			done
		else
			echo "one of the languages is NOT on stopwort_uni_trigramm_list.ini" >> $log
			keep_all $basename
		fi
	else
		echo "${tld_prefix} is NOT on tld-list: ${tld_list_local}" >> log
		keep_all $basename
	fi
}

#########################################################################################
#	select outputs of langSepa 
#########################################################################################
select_output()
	{
		echo "start output selection " >> $log
	 	date >> $log
		basename=$1
		prefix="$( get_prefix $basename )"
		if [ ${#prefix} -eq 3 ]; then # when 3 character -> lang
			echo "selecting output with method select_output_lang()" >> $log
			date >> $log
			select_output_lang $prefix $basename
		else  # when 2 character -> tld
			echo "selecting output with method select_output_TLD()" >> $log
			date >> $log
			select_output_tld $prefix $basename
		fi
	}