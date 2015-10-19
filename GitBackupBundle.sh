# How to limit depth for recusive file list
# http://stackoverflow.com/questions/4509624/how-to-limit-depth-for-recursive-file-list
# man page of find command
# http://ss64.com/bash/find.html
# man page of xargs command
# http://ss64.com/bash/xargs.html


projects="/d/project" 									#set root for all git repo 
backups="/d/backup" 									#set backup directory
logfn=log_backups_"$(date +%Y%m%d -d "today")"			#set log files name
logf="/d/backup/logs/${logfn}"							#set log files path

#find directory path for all git repo
paths=$(find "$projects" -name ".git" -mindepth 2 -maxdepth 2 -type d -print0 | xargs -0 ls -d)


# iterating over lines in a variable
# http://superuser.com/questions/284187/bash-iterating-over-lines-in-a-variable

#iterating over all git repo path list in "paths"
while read -r path;do
	#echo "This is full repo path include .git: ${path}"
	
	path="${path%/.git*}" 	# This removes all cheracters (*) before first met pattern (/.git) from end (%) of parameter (${path})	
	# http://stackoverflow.com/questions/2059794/what-is-the-meaning-of-the-0-syntax-with-variable-braces-and-hash-chara 
	# http://www.ibm.com/developerworks/library/l-bash-parameters/index.html
	
	echo "This is full repo path without .git: ${path}"
	
    d=`date +%Y%m%d%H%M%S`
	
    #echo "This is current date & time: ${d}"
	
	echo "--------- (${d}) ${path}" >> ${logf} #output backup log to log file
	
    name="${path##*/}" #This removes all character (*) before last meet pattern (/) from begining(##) of parameter (${path})
	
    #name="${name%.git}"
    echo "${name}"
	
	#TODO: use repo path to create git bundle 
	
done <<< "$paths" #This line is crucial, "$paths" must passed as argument.

