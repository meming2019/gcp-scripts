#!/bin/bash

# This script automates the scanning of a tree of app code bases using CAST Highlight CLI
# 1. rename the attached script to scan_all.sh and upload it to your CAST CLI work directory (where HighlightAutomation.jar is) in your Linux VM
# 2. chmod a+x scan_all.sh
# 3. edit the script and update the "output_home" variable to a directory path that's new
# 4. Run "./scan_all.sh <apps home path>" from the work directory 

# Below is a sample env:
# 1. ./apps_root is the parent directory of all the app directories, aka <app home path>
# 2. ./outputhome/* has all the scan results
# 3. The .zip files in the output directories corresponding to the apps are what need to be uploaded to CAST portal (more details later)

cast_cli_jar_path=./HighlightAutomation.jar
output_home=./outputhome

appnum=0 

mkdir ${output_home}

for appname in $1/*; do
    if [ -d "${appname}" ]; then
	curr_working_dir="${output_home}/output_${appnum}"
	mkdir ${curr_working_dir}
	appname_str=`tr -s ". /" _ <<< "${appname}"`
	curr_output_filename="${curr_working_dir}/cast_output_app_${appnum}_${appname_str}.zip"

        echo "Scanning [${appnum}] ${appname}... Output file is ${curr_output_filename}"
	java -jar ${cast_cli_jar_path}  --workingDir "${curr_working_dir}" --sourceDir "${appname}" --skipUpload --zipResult "${curr_output_filename}"
	((appnum=appnum+1))
    fi
done
