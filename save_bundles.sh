#! /bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DIR=${DIR%/*}
# echo DIR=$DIR
cd "${DIR}"
H="${DIR}"
source "${DIR}/.bashrc" --force > /dev/null

function date_unix() {
  local date1="${1}"
  local _udate="${2}"

  local d="${date1}"
  local dd="${d:0:4}-${d:4:2}-${d:6:2} ${d:8:2}:${d:10:2}:${d:12:2}"

  audate=$(date -d "$dd" +%s)

  eval ${_udate}="'${audate}'"
}

function date_day() {
  local date1="${1}"
  local _dname="${2}"

  local d="${date1}"
  local dd="${d:0:4}-${d:4:2}-${d:6:2} ${d:8:2}:${d:10:2}:${d:12:2}"

  adname=$(date -d "$dd" +%a)

  eval ${_dname}="'${adname}'"
}

function date_delta() {
  local date1="${1}"
  local date2="${2}"
  local _delta="${3}"

  local d=${date1}
  # echo "date1 $d"
  local d1
  date_unix $d d1
  d=${date2}
  # echo "date2 $d"
  local d2
  date_unix $d d2
  # echo "date1 unix $d1 date2 unix $d2" 

  local delta=$(( ${d2} - ${d1} ))

  local sign
  if [[ $delta -lt 0 ]]
  then sign="-"; delta=${delta/^-/}
  else sign="+"
  fi

  local ss=$(( $delta % 60 ))
  delta=$(( $delta / 60 ))
  local mm=$(( $delta % 60 ))
  delta=$(( delta / 60 ))
  local hh=$(( $delta % 24 ))
  local dd=$(( $delta / 24 ))

  adelta=$(printf "$sign%d %.2d:%.2d:%.2d\n" $dd $hh $mm $ss)
  # echo "adelta ${adelta}"

  eval ${_delta}="'${adelta}'"
}

source "${H}/sbin/usrcmd/get_hostname"
get_hostname hostnames
source "${H}/sbin/usrcmd/get_fqn"
get_fqn ${hostnames} fqn

if [[ -e "${H}/../.nobackup" ]]; then
  echo "No backup for '${fqn}'"
  exit 0
fi

repos="${H}/repositories"
bkp="${H}/../backups"
paths=$(ls -1 "${repos}"|grep ".git")

logfn=log_backups_"$(date +%Y%m%d -d "today")"
logf="${H}/mcron/logs/${logfn}"
mkdir -p "${H}/mcron/logs"
ln -fs "logs/${logfn}" "${H}/mcron/log_backups"
logfb="${H}/mcron/logs/logs_backups"

status=0
stexit=0
while read -r path; do
    d=`date +%Y%m%d%H%M%S`
    path="${H}/repositories/${path}"
    echo "--------- (${d}) $path" >> ${logf}
    name="${path##*/}"
    name="${name%.git}"
    # echo "${name}"
    f=$(ls -t "${bkp}/${name}"* 2> /dev/null)
    # echo $f
    if [[ "${f}" == "" ]] ; then 
	  echo "${name} no backups found => Create FULL backup." >> "${logf}"
      d=`date +%Y%m%d%H%M%S`
      _dd=${d:0:8}
      _dt=${d:8:6}
      describe=$(git -C "${path}" rev-parse --short=10 HEAD 2>/dev/null)
      if [[ "${describe}" == "" ]]; then
        echo "${name} is an EMPTY repo => no backup to do." >> "${logf}"
      else
        echo "FULL to ${bkp}/${name}-${d}-${describe}-full.bundle" >> "${logf}"
        echo "${d} FULL to ${bkp}/${name}-${d}-${describe}-full.bundle" >> "${logfb}"
        git -C "${path}" bundle create "${bkp}/${name}-${d}-${describe}-full.bundle" --all
        status=$?
        if (( ${status} != 0 )); then stexit=${status}; fi
      fi
      # exit 0
    else
      fname=${f%%bundle*}
      # echo 1 $fname
      fname=${fname##*/${name}-}
      # echo 2 $fname
      fname=${fname%-*}
      # echo 3 $fname
      # exit 0
      d=${fname%%-*}
      _dd=${d:0:8}
      _dt=${d:8:6}
      s=${fname##*-}
      nowd=`date +%Y%m%d%H%M%S`
      # echo "now $nowd, vs. d $d s $s from ls $f"
      date_unix ${nowd} nu
      # echo "now $nowd, vs. d $d:"
      date_day $d dn
      date_day ${nowd} nowdn
      date_delta $d ${nowd} dd1
      # echo "delta ${dd1} (${dn}) nowu ${nu} (${nowdn})"
      dd2=${dd1%% *}
      dd2="${dd2#*+}"
      # echo "dd2 ${dd2}"

      # http://stackoverflow.com/questions/2953646/how-to-declare-and-use-boolean-variables-in-shell-script 
      incr=false
      if [[ "${dd1:0:2}" == "+0" ]]; then
        if [[ "${nowdn}" == "Sun" ]]; then
          if [[ "${dn}" == "Sun" ]]; then
            echo "${name}: two or more backups on Sun: incremental" >> "${logf}"
            incr=true
          else
            echo "${name}: first backup on Sunday: FULL" >> "${logf}"
          fi
        else
          echo "${name} less than 24h since last backup: incremental" >> "${logf}"
          incr=true
        fi
      else
          #echo "dd2 to be tested: ${dd2}"
          if (( ${dd2} > 6 )); then
            echo "${name}: More than 6 days since last backup: full" >> "${logf}"
          else 
            echo "${name}: 6 or less since last backup: incremental" >> "${logf}"
            incr=true
          fi
      fi
      # http://askubuntu.com/questions/385528/how-to-increment-a-variable-in-bash
      nbd=$((++dd2))
      # echo "dd2='${dd2}', vs. nbd='${nbd}'"
      describe=$(git -C "${path}" log --abbrev=10 --pretty=format:%h --since=${nbd}.days.ago --all -1 2>/dev/null)
      # echo "now: ${describe} vs. s ${s}"
      if [[ "${describe}" == "" || "${describe}" == "${s}" ]]; then
        echo "No new commit detected since last backup ${_dd}-${_dt}[${s}]: no need for backup for '${name}'" >> "${logf}"
      elif [[ "${incr}" == "true" ]]; then
        echo "Create INCREMENTAL backup for '${name}' (previous was ${_dd}-${_dt}[${s}]" >> "${logf}"
        echo "${nowd} Create INCREMENTAL backup for '${name}' (previous was ${_dd}-${_dt}[${s}]" >> "${logfb}"
        git -C "${path}" bundle create "${bkp}/${name}-${nowd}-${describe}-incr.bundle" --since=${nbd}.days.ago --all
        status=$?
        if (( ${status} != 0 )); then stexit=${status}; fi
      else
        echo "Create FULL backup bundle for '${name}'." >> "${logf}"
        echo "${nowd} FULL to ${bkp}/${name}-${nowd}-${describe}-full.bundle" >> "${logfb}"
        git -C "${path}" bundle create "${bkp}/${name}-${nowd}-${describe}-full.bundle" --all
        status=$?
        if (( ${status} != 0 )); then stexit=${status}; fi
      fi
      #exit 0
    fi
    nowd=`date +%Y%m%d%H%M%S`
    #cd "${H}/${path}"
    #git bundle create "$1/${name}.bundle" --all
    # :http://superuser.com/questions/284187/bash-iterating-over-lines-in-a-variable
    lastfbd=$(ls -r1 "${bkp}/${name}-"*"-full.bundle" 2>/dev/null|head -1)
    bds=$(ls -r1 "${bkp}/${name}-"* 2>/dev/null)
    delbd=false
    while read -r abd; do
      #echo $abd
      if [[ "${delbd}" == "true" && "${abd}" == "${abd%-full.bundle}" ]]; then
        echo "${nowd} deleting ${abd}" >> "${logfb}"
        /bin/rm -f "${abd}"
      elif [[ "${abd}" != "${abd%-full.bundle}" && "${abd}" == "${lastfbd}" ]] ; then
        # echo "Start deleting after ${abd}"
        delbd=true
      fi
    done <<< "${bds}"
    bds=$(ls -r1 "${bkp}/${name}-"*"-full.bundle" 2>/dev/null)
    delbd=false
    nb=1
    while read -r abd; do
      if (( ${nb} > 3 )); then
        echo "${nowd} Trimming FULL backup $abd" >> "${logfb}"
        /bin/rm -f "${abd}"
      fi
      nb=$((++nb))
    done <<< "${bds}"
done <<< "$paths"

exit ${stexit}

# http://stackoverflow.com/questions/20831765/find-difference-between-two-dates-in-bash
# http://stackoverflow.com/questions/5885934/bash-function-to-find-newest-file-matching-pattern
# http://stackoverflow.com/questions/5025087/how-do-i-get-the-commit-id-of-the-head-of-master-in-git
# http://stackoverflow.com/questions/18668556/comparing-numbers-in-bash
# http://stackoverflow.com/questions/7285059/hmac-sha1-in-bash
