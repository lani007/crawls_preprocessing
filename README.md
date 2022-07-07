"crawls_preprocessing" is used to automate the process from 
*warcExtractor* OR *langSepa* until selection of the outputs of *langSepa*.

## Input file format

The program takes the following input file:
1. the outputs from web crawler in format `*.warc.gz`
2. the outputs from *warcExtractor* in format `*.source`

## Workflows

Depends on the input file format, different workflow will be selected automatically.
1. `wf_from_warc()` : `*.warc.gz` &rarr; *warcExtractor* &rarr; `*.source` &rarr; *langSepa* &rarr; `*.txt` &rarr; output_select
2. `wf_from_langSepa()` : `*.source` &rarr; *langSepa* &rarr; `*.txt` &rarr; output_select &rarr; `*.tar.gz`

* These workflows are defined in `wf_types.sh`.
* The functions used in `wf_types.sh` are defined in `wf_functions.sh` and `db_functions.sh`.

The prefix of input files (followed by an underscore '_' ) shall follow these rules:
1. two charactor prefix (tld-prefix) are for files crawled by top level domain (tld), e.g. `de_web_2015.01668.warc.source`
2. three charactor prefix (lang-prefix) are for files crawled by language, e.g. `fin_news.00004.warc.gz`

## Output selection rules

`BASENAME` := input file name without suffix

E.g. input file = `de_web_2015.01668.warc.source` --> `BASENAME` = `de_web_2015.01668`

The output files from *langSepa* will be selected by following rules:
- only files with `LANG_0000.txt` are kept
- which languages to keep (the `LANG` part) is determined by the prefix of the input `*.source` file:
1. tld-prefix: all languages (if exist after *langSepa*) listed in the file `TLD_commonlang.txt` under the specific tld will be kept. If tld-prefix is not on `TLD_commonlang.txt`, all outputs from *langSepa* are kept.
2. lang-prefix: only the 'lang' specified in the input file name is kept

After which languages to keep is determined, the following naming and selection rules are applied for each language:
- `BASENAME_LANG_stopwort.txt`:  if language is on '`stopwort_list.ini` list, its output in Stopwort-folder is kept
- `BASENAME_LANG_uni.txt` & `BASENAME_LANG_tri.txt` :  if language is on `uni_trigramm_list.ini` list, its output in Trigramm- AND Unigramm-folders are kept
- `BASENAME.all.tar.gz` :  language not on any list above, keep all outputs from *langSepa*

At the end of each workflow, following .tar.gz files are generated and copied to `$output`
1. `BASENAME.all.tar.gz`: this file is generated from two cases:
	1. if tld-prefix is not on `TLD_commonlang.txt`  
	2. if any of the languages to keep is not on `stopwort_list.ini` and `uni_trigramm_list.ini`
2. `BASENAME.selected.tar.gz`: if all wanted languages are listed in `stopwort_list.ini` or `uni_trigramm_list.ini`, all outputs from a workflow (`BASENAME_LANG_stopwort.txt` and `BASENAME_LANG_uni.txt` and `BASENAME_LANG_tri.txt`) are pulled and compressed as this file


## Database

to create MySQL database tables to keep track of job status, run `create_preprocessing_tables.sql`


## Configurations

Before running this preprocessing program, these settings shall be set up:
1. set `WORKING_DIRECTORY` (absolute dir) at the first line of file 
    `src/preprocessing_main.sh`
2. set parameters in `cfg/prepro.cfg`
- when running in a new server, fields to be changed are denated with **
- NOTE: file `LangSepa.ini` : parameter tunning for `LangSepa.jar` 
  Due to parsing rules in preprocessing program, please do not set PREFIX in `LangSepa.ini` !!!


## To run Preprocessing Program

1. make a `WORKING_DIRECTORY`, e.g. `prepro_0104`
2. copy folder preprocessing into `WORKING_DIRECTORY`
3. navigate into `WORKING_DIRECTROY`
4. run preprocessing by

```
(nohup) ./src/run_preprocessing.sh WORKING_DIRECTORY &
```

## Structure of folders

1. workflows are run under `WORKING_DIRECTORY/run_prepro`
2. outputs of each workflow are moved to `${destination}`
3. folders/files under `WORKING_DIRECTORY`:
```
create_preprocessing_tables.sql  
cfg/
src/
run_prepro 
FINISHED_JOB_LOG 
log    
 ```
4. folders/files inside each workflow (`WORKING_DIRECTORY/run_prepro/BASENAME`):
```
BASENAME.log  
f1_warc_gz_dir  
f2_warcExtractor_dir
f3_langSepa_dir  
f4_selected_output  
TLD_commonlang.txt  
stopwort_list.ini             
uni_trigramm_list.ini   
stopwort_uni_trigramm_list.ini   
tools.jWarcEx-0.0.1-SNAPSHOT.jar
```

## logs

1. `WORKING_DIRECTORY/log`: document the start of each workflow
2. `WORKING_DIRECTORY/run_prepro/BASENAME/BASENAME.log`: document the stages of the workflow `BASENAME`
- single preprocessing logs i.e. 2. are moved to `FINISHED_JOB_LOG` folder after finished


## programm logic

1. get folder (in `run_preprocessing.sh`):
	folders in the `cfg/piority_folder.ini` are dealt first	then, all folders in `${file_source}` are dealt, the oldest folder first

2. get file list within each folder (in `run_preprocessing.sh`):
	all files, which are not modified in the last one minute is saved into a list and passed to command "parallel" to run

3. check file status (in `preprocessing_main.sh`):
	It is firstly checked against the database if a file is already preprocessed before by:
	1. if the file is in database 
	2. if the file shows 'finished' at "*langSepa*" column in database
	If and only if both conditions are true, the original file in `${file_source}` is removed and next file on the input list is called.


