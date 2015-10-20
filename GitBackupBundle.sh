
projects="/d/project" 									#set root for all git repo 
backups="/d/backup" 									#set backup directory
logfn=log_backups_"$(date +%Y%m%d -d "today")"			#set log files name
logf="/d/backup/logs/${logfn}"							#set log files path
logfb="/d/backup/logs/logs_backups"						#set logs_backups files path(why?)


# How to limit depth for recusive file list
# http://stackoverflow.com/questions/4509624/how-to-limit-depth-for-recursive-file-list
# man page of find command
# http://ss64.com/bash/find.html
# man page of xargs command
# http://ss64.com/bash/xargs.html
paths=$(find "$projects" -name ".git" -mindepth 2 -maxdepth 2 -type d -print0 | xargs -0 ls -d) #find directory path for all git repo

paths="/d/Project/AmiKernalCode/.git/" #only for test, should be removed

# iterating over lines in a variable
# http://superuser.com/questions/284187/bash-iterating-over-lines-in-a-variable
while read -r path;do #iterating over all git repo path list in "paths"
	
	# What is the meaning of the ${0##…} syntax with variable, braces and hash character in bash?
	#http://stackoverflow.com/questions/2059794/what-is-the-meaning-of-the-0-syntax-with-variable-braces-and-hash-chara 
	# Linux tip: Bash parameters and parameter expansions
	# http://www.ibm.com/developerworks/library/l-bash-parameters/index.html
	path="${path%/.git*}" 	# This removes all cheracters (*) before first met pattern (/.git) from end (%) of parameter (${path})	
	
    d=`date +%Y%m%d%H%M%S`
	
	echo "--------- (${d}) ${path}" >> ${logf} #output backup log to log file
	
    name="${path##*/}" #This removes all character (*) before last meet pattern (/) from begining(##) of parameter (${path})
	
	# https://www.kernel.org/pub/software/scm/git/docs/
	# -C <path> 			Run as if git was started in <path> instead of the current working directory. 
	
	# https://www.kernel.org/pub/software/scm/git/docs/git-rev-parse.html
	# rev-parse				Pick out and massage parameters
	# --short=number		Instead of outputting the full SHA-1 values of object names try to abbreviate them to a shorter unique name. When no length is specified 7 is used. The minimum length is 4.
	# HEAD					names the commit on which you based the changes in the working tree.
	
	# http://askubuntu.com/questions/350208/what-does-2-dev-null-mean
	# 2> file 				redirects stderr to file
	# /dev/null 			is the null device it takes any input you want and throws it away. It can be used to suppress any output.
	describe=$(git -C "${path}" rev-parse --short=10 HEAD 2>/dev/null) # get 10-digits of SHA1 of HEAD and ignore error.
	
	if [[ "${describe}" == "" ]]; then
		echo "${name} is an EMPTY repo => no backup to do." >> "${logf}"
	else
		echo "FULL to ${bkp}/${name}-${d}-${describe}-full.bundle" >> "${logf}"
        echo "${d} FULL to ${backups}/${name}-${d}-${describe}-full.bundle" >> "${logfb}"
		git -C "${path}" bundle create "${backups}/${name}-${d}-${describe}-full.bundle" --all
		
		# What is the $? variable in shell scripting?
		# http://stackoverflow.com/questions/6834487/what-is-the-variable-in-shell-scripting
		# $? 		is used to find the return value of the last executed command.
	    status=$?
		
        if (( ${status} != 0 )); then stexit=${status}; fi
	fi
	
	# TODO: create incremental backup bundle 
	
done <<< "$paths" #This line is crucial, "$paths" must passed as argument.

# Chapter 6. Exit and Exit Status
# http://tldp.org/LDP/abs/html/exit-status.html
exit ${stexit}
		
	# TODO: add restore function
	#git clone --mirror "/d/backup/IBD_TOD_10CU-20151020-test-full.bundle" "/d/Project/IBD_TOD_10CU.bak/.git"