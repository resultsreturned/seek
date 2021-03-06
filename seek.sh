# seek - v1.2
# Search directories for file
#
# Copyright (C) 2013 Mara Kim
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see http://www.gnu.org/licenses/.


### USAGE ###
# Source this file in your shell's .*rc file

# search using find
function seek {
    # read arguments
    local option
    local preoption
    local printoption
    local execoption
    local op_cd
    local input
    local rawinput
    local state
    local appender
    appender='('
    for arg in "$@"
    do
        if [ "$state" = "input" ]
        then
            input+=("$appender" '(' -name "*${arg##*/}*" -path "*${arg//\//*/*}*" ')' )
            rawinput+=("$arg")
            appender='-o'
        elif [ "$arg" = "-?" -o "$arg" = "-h" -o "$arg" = "--help" ]
        then
            printf 'Usage: seek [OPTION] [PATTERN]
Search the current directory and any children for files matching PATTERN.
Patterns automatically wildcard slashes (ie. / = */* )
  Option	Meaning
  -, -cd, -to	Change directory to the deepest directory containing all matches
  +command	Pass matches as arguments to command, replacing `{}` with matching files.
  -*		Pass argument to find. Colons are interpreted as spaces (ie. -type:d = -type d)
  -h, -?	Show help
See `man find`.
'
            return 0
        elif [ "$arg" = "--" ]
        then
            state="input"
        elif [ -z "${arg##+*}" -a "${arg#+}" ]
        then
            execoption+=( '-execdir' 'bash' '-c' "eval ${arg#+}" ';' )
        elif [ -z "${arg##-*}" ]
        then
            if [ "$arg" = "-" -o "$arg" = "-cd" -o "$arg" = "-to" ]
            then
                op_cd="1"
            elif [ "$arg" = "-P" -o "$arg" = "-L" -o "$arg" = "-H" ]
            then
                preoption="$arg"
            elif [ -z "${arg##-*print*}" ]
            then
                printoption+=( ${arg//:/ } )
            else
                option+=( ${arg//:/ } )
            fi
        else
            input+=("$appender" '(' -name "*${arg##*/}*" -path "*${arg//\//*/*}*" ')' )
            rawinput+=("$arg")
            appender='-o'
        fi
    done

    # search using find, no parameters
    if [ -z "$input" ]
    then
        find $preoption "$PWD" "${option[@]}" "${printoption[@]}" "${execoption[@]}"
        return $?
    fi

    input+=( ')' )
    if [ "$op_cd" ]
    then
        # find lowest unambiguous subdiretory containing all matches
        local targets
        local target
        while read -r -d '' target
        do
            targets+=( "$target" )
        done < <(find $preoption "$PWD" "${input[@]}" "${option[@]}" -print0)

        if [ "${#targets[@]}" -lt 1 ]
        then
            printf 'Not found: %b\n' "${rawinput[@]}" 1>&2
            return 1
        else
            local finder
            local trimmer
            target="$targets"
            trimmer="${target/%\/*//}"
            target="${target#$trimmer}"
            while [ -z "$(\printf '%b' "${targets[@]##$finder$trimmer*}")" -a "$target" ]
            do
                finder+="$trimmer"
                trimmer="${target/%\/*//}"
                target="${target#$trimmer}"
            done
            local filter
            filter="${targets[@]#$targets}"
            if [ -z "$target" -a -d "$finder$trimmer" -a -z "$(printf '%b' "${filter##/*}")" ]
            then
                finder+="$trimmer"
            fi

            printf '%b\n' "${targets[@]}"
            if [ "$(readlink -e -- "$finder")" != "$(readlink -e -- "$PWD")" ]
            then
                cd -- "$finder"
                return $?
            else
                return 1
            fi
        fi
    else
        # search with parameters
        find $preoption "$PWD" "${input[@]}" "${option[@]}" "${printoption[@]}" "${execoption[@]}"
        return $?
    fi
}

