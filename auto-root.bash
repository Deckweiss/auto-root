#!/usr/bin/env bash

# Parse options
for opt in "$@"; do
  case $opt in
  useExitCode) useExitCode=1 ;;
  useSu) useSu=1 ;;
  debug) debugOut=1 ;;
  disableTildeExpansion) tildeExpansion=0 ;;
  *) echo -e "auto-root: unknown option: $opt" 1>&2 ;;
  esac
done

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
  'must run this script as root'
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
  'superuser access required'
)

function getRelevantParentPid() {
  pidTree=$(pstree -spA $$)

  if grep -q zsh <<<"$pidTree"; then
    relevantShellName=zsh
  elif grep -q bash <<<"$pidTree"; then
    relevantShellName=bash
  else
    relevantShellName=${SHELL##*/}
  fi

  relevantParentPid=$(echo "$pidTree" | sed "s/${relevantShellName}(\([0-9]*\)).*$/\1/" | sed 's/^.*---\([0-9]*\)/\1/')

  if [[ $debugOut == 1 ]]; then
    touch "$HOME/auto-root.log"
    echo "shell name: ${relevantShellName}" >&2
    echo "pid tree: ${pidTree}" >&2
    echo "parent pid: ${relevantParentPid}" >&2
    echo "${relevantParentPid}/$$ : shell name: ${relevantShellName}" >>"$HOME/auto-root.log"
    echo "${relevantParentPid}/$$ : pid tree: ${pidTree}" >>"$HOME/auto-root.log"
    echo "${relevantParentPid}/$$ : parent pid: ${relevantParentPid}" >>"$HOME/auto-root.log"
  fi

  echo "$relevantParentPid"
}

#$BASHPID id of the current terminal session
parentPid=$(getRelevantParentPid $BASHPID)
tempfile=${autoRootTempFileDir:=$HOME}/terminal_${parentPid}.tmp

function printDebug() {
  if [[ $debugOut == 1 ]]; then
    touch "$HOME/auto-root.log"
    echo "$parentPid/$$ : $1" >>"$HOME/auto-root.log"
    echo "$1"
  fi
}

function startAutoRootSession() {
    local autoRootDisabled="${AUTO_ROOT_DISABLE:-0}"

    if [[ $autoRootDisabled == 1 ]]; then
      printDebug "auto-root disabled"
      return 0
    else
      printDebug "auto-root enabled"
    fi

  if [[ -e "$tempfile" ]]; then
    printDebug "tempfile already exists: $tempfile"
  else
    clear

    # Create directory to write temp files to if it doesn't exists
    if [[ -d "$autoRootTempFileDir" ]]; then
      printDebug "$autoRootTempFileDir exists"
    else
      printDebug "$autoRootTempFileDir created"
      mkdir -p "$autoRootTempFileDir"
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

#https://stackoverflow.com/a/29310477
function expandPath() {
  local path
  local -a pathElements resultPathElements
  IFS=':' read -r -a pathElements <<<"$1"
  : "${pathElements[@]}"
  for path in "${pathElements[@]}"; do
    : "$path"
    case $path in
    "~+"/*)
      path=$PWD/${path#"~+/"}
      ;;
    "~-"/*)
      path=$OLDPWD/${path#"~-/"}
      ;;
    "~"/*)
      path=$HOME/${path#"~/"}
      ;;
    "~"*)
      username=${path%%/*}
      username=${username#"~"}
      IFS=: read -r _ _ _ _ _ homedir _ < <(getent passwd "$username")
      if [[ $path == */* ]]; then
        path=${homedir}/${path#*/}
      else
        path=$homedir
      fi
      ;;
    esac
    resultPathElements+=("$path")
  done
  local result
  printf -v result '%s:' "${resultPathElements[@]}"
  printf '%s\n' "${result%:}"
}

function autoRootEvaluate() {
  local autoRootDisabled="${AUTO_ROOT_DISABLE:-0}"

  if [[ $autoRootDisabled == 1 ]]; then
    printDebug "auto-root disabled"
    clearLoggingSession
    return 0
  else
    printDebug "auto-root enabled"
  fi

  if [[ $useExitCode == 1 ]]; then
    if [[ $? ]]; then
      printDebug "No error exit status returned by last command. Exit code: $?"
      return 0
    fi
  fi

  local shouldRerunAsRoot=false

  if [[ ! -e "$tempfile" ]]; then
      printDebug "tempfile does not exist"
      return 0
  fi

  for str in "${patterns[@]}"; do
    if grep -iqF "$str" "$tempfile"; then
      printDebug "it should be re-run as root because '$str' matched"
      shouldRerunAsRoot=true
      break
    fi
  done

  clearLoggingSession

  if $shouldRerunAsRoot; then
    printDebug "Previous command raw: '$previous_command'"
    local command_to_run=""

    read -ra splitCommandParts <<<"$previous_command"
    for a in "${splitCommandParts[@]}"; do
      printDebug "Expanding path for [$a]"
      commandPart=$(expandPath "$a")
      printDebug "$commandPart"
      command_to_run="$command_to_run$commandPart "
    done

    printDebug "Previous command expanded: '$command_to_run'"

    if [[ $useSu == 1 ]]; then
      printDebug "re-running '$command_to_run' with su"
      su -c "$command_to_run"
    else
      printDebug "re-running '$command_to_run' with sudo"
      sudo -k bash -c "$command_to_run"
    fi
  fi
}
