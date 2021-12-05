# auto-root
A script that automatically reruns your last command as root if you forgot it.

![auto-root](https://user-images.githubusercontent.com/10449980/144729941-8b0ce1be-f234-4f15-8254-5d110dab7102.gif)

This tool is for people like me, who forget to prepend commands with `sudo` and are annoyed by the additional step of typing `sudo !!`.

It will ALWAYS ask for a password, to prevent executing something as root without the user noticing.

## configuration:

You can configure the location of the necessary temp files by modifying `autoRootTempFileDir` in your .bashrc (By default your `tmpfs` mountpoint is used, which writes the temp files to ram/swap)

You can add the following options to the source statement in your .bashrc file

- `useExitCode` checks exit code of last command. Slightly better performance, but does not work when cancelling commands (for example a cancel in the middle of `find /` will not rerun with root if this option is enabled) or scripts that do not reliably output an exit code when running into a permissions error
- `useSu` uses su instead of sudo
- `debug` prints verbose output and collects the output of all sessions to ~/auto-root.log

Example: `source /opt/auto-root/auto-root.bash useSu debug`

## dependencies:

- `bash`
- `su` or `sudo`
- `script` from `util-linux`
- multiple tools from `coreutils`

## install:

Download/clone the repo and run the install script. Can be re-run safely for updating. 
!!! The install script modifies your ~/.bashrc non destructively !!!

Better ways to install are comming in the future.

## how it works:

1. When you open an interactive bash terminal, a temporary file is created for this session. This way, the outputs from multiple terminals do not get in each others way.
2. Running a command saves the output of that command to the temp file, `script` is used to accomplish this.
3. After the command is finished running or canceled, it is checked if any of the matching patterns from a list can be found in the temp file. If so, the last command is re-run with sudo or su. 
4. The temp file is cleared of any content and is ready for the next command.
5. When the interactive bash session is closed, it's temp file is deleted.

## TODO:

- [ ] improve getRelevantParentPid function
- [ ] document how this works
- [ ] package for Debian based distros
- [ ] package for Arch based distros
- [ ] release on AUR

## Credit:

This tool would not exist without the following things:

- initial inspirations from https://github.com/agura-lex/find-the-command
- list of permission related patterns from https://github.com/nvbn/thefuck/blob/master/thefuck/rules/sudo.py
- brainstorming ideas and discussing it with the amazing Archlinux community on https://www.reddit.com/r/archlinux/comments/qkhvbh/is_there_an_autosudo_for_terminal/
- bash scripting help and general hackery by https://github.com/theAkito

## Notice:

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.

