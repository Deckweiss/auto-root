#!/usr/bin/env bash

declare -a patterns=(
  'permission denied'
  'eacces'
  'pkg: insufficient privileges'
  'you cannot perform this operation unless you are root'
  'non-root users cannot'
  'operation not permitted'
  'root privilege'
  'this command has to be run under the root user.'
  'this operation requires root.'
  'requested operation requires superuser privilege'
  'must be run as root'
  'must run as root'
  'must be superuser'
  'must be root'
  'need to be root'
  'need root'
  'needs to be run as root'
  'only root can '
  'you don'"'"'t have access to the history db.'
  'authentication is required'
  'edspermissionerror'
  'you don'"'"'t have write permissions'
  'use `sudo`'
  'sudorequirederror'
  'error: insufficient privileges'
)

# TODO ↓ can be improved for better cross platform support

# Look up the one before top-level parent Process ID (PID) of the given PID, or the current
# process if unspecified.
function getRelevantParentPid() {
  # Look up the parent of the given PID.
  pid=${1:-$$}
  lastChildPid=${2}
  stat=($(</proc/${pid}/stat))
  ppid=${stat[3]}

  # /sbin/init always has a PID of 1, so if you reach that, the PID is the top-level parent.
  # And the lastChildPid is the relevant parent.
  # (for example /init/plasmashell/konsole/bash/script - returns pid of konsole)
  # Otherwise, keep looking.
  if [[ ${ppid} -eq 1 ]]; then
    echo "${lastChildPid}"
  else
    getRelevantParentPid "${ppid}" "${pid}"
  fi
}

#$BASHPID id of the current terminal
parentPid=$(getRelevantParentPid $BASHPID)
tempfile=${tempfilesPath:=$HOME}/terminal_${parentPid}.tmp

# Print to stderr
alias printError='echo -e 1>&2'

function printDebug() {
  if [[ $debugOut == 1 ]]; then
    touch "$HOME/auto-sudo.log"
    echo "$1"
    echo "$parentPid/$$ : $1" >>"$HOME/auto-sudo.log"
  fi
}

# Parse options
for opt in "$@"; do
  case $opt in
  useExitCode) useExitCode=1 ;;
  su) useSu=1 ;;
  debug) debugOut=1 ;;
  *) printError "auto-sudo: unknown option: $opt" ;;
  esac
done

function startAutoRootSession() {
  if [[ -e "$tempfile" ]]; then
    printDebug "tempfile already exists: $tempfile"
  else
    clear

    # Create directory to write temp files to if it doesn't exists
    if [[ -d "$tempfilesPath" ]]; then
      printDebug "$tempfilesPath exists"
    else
      printDebug "$tempfilesPath created"
      mkdir -p "$tempfilesPath"
    fi

    touch "$tempfile"
    script -fq "$tempfile"
    printDebug "tempfile created: $tempfile"
  fi
}

function stopAutoRootSession() {
  if [[ -e "$tempfile" ]]; then
    printDebug "removing tempfile $tempfile"
    rm "$tempfile"
    exit
  else
    printDebug "tempfile does not exist"
  fi
}

function clearLoggingSession() {
  printDebug "clearing tempfile"
  truncate -s 0 "$tempfile"
}

function autoRootEvaluate() {
  if [[ $useExitCode == 1 ]]; then
    if [[ $? ]]; then
        printDebug "No error exit status returned by last command. Exit code: $?"
        return 0
    fi
  fi

  shouldRerunAsRoot=false
  for str in "${patterns[@]}"; do
    if grep -iqF "$str" "$tempfile"; then
      shouldRerunAsRoot=true
      break
    fi
  done

  clearLoggingSession
  if $shouldRerunAsRoot; then
    if [[ $useSu == 1 ]]; then
      printDebug "re-running '$previous_command' with su"
      su -c "$previous_command"
    else
      printDebug "re-running '$previous_command' with sudo"
      sudo -k bash -c "$previous_command"
    fi
  fi
}
