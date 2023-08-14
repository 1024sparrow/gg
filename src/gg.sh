#!/bin/bash

declare i iArg state=initial
declare -a gitArguments

function ERROR {
	echo $1 >& 2
	exit 1
}

RED='\e[0;31m'
GREEN='\e[0;32m'
YELLOW='\e[0;33m'
#YELLOW='\e[0;33m\e[41m'  # на красном фоне
NC='\033[0m' # No Color

function fTest {
	for i in node git
	do
		if ! which $i > /dev/null
		then
			ERROR "Для работы утилиты необходимо установить в систему утилиту \"$i\""
		fi
	done
}

for iArg in "$@"
do
	if [ "$iArg" == --help ]
	then
		echo '
gg - обёртка над системной утилитой git. Обеспечивает следующие вещи:
  * делает более прозрачной работу с git submodules
  * добавляет сущность task и приводит формирование веток к взятию-вливанию задач
  * экранирует опасные команды git, такие как "git rebase"

Получить текущее состояние всех git-submoodules текущего репозитория - gg status
'
		fTest
		exit 0
	fi
done

function getIndent {
	local argRetValIndent=$1
	local argRoot=$2
	local argPlace=$3

	local tmp=$argPlace
	local -i i

	for ((i = 0 ; i < 100 ; ++i))
	do
		tmp=$(dirname $tmp)
		if [ $tmp == "$argRoot" ]
		then
			tmp=
			for ((ii=0 ; ii < $i ; ++ii))
			do
				#tmp="####$tmp"
				tmp="    $tmp"
			done
			eval "$argRetValIndent=\"$tmp\""
			return 0
		fi
	done
	eval $argRetValIndent=
}

function showGitStatusPart {
	local argRoot="$1"
	local argSubroot="$2"

	local state=0
	local indent
	getIndent indent $argRoot $argRoot/$argSubroot
	#echo "getIndent indent $argRoot $argSubroot"
	#echo "indent: \"$indent\""

	:||'
States:
0 - initial
1 - branch taken
2 - up-to-date confirmed
3 - not staged for commit
4 - untracked files
'

	#echo -e " ${YELLOW}1234${NC}"
	echo -en "$indent$YELLOW$argSubroot$NC"
	while read line
	do
		if [ -z "$line" ]
		then
			state=1
			echo
		fi

		if [ $state == 0 ]
		then
			if [[ "$line" =~ ^On\ branch ]]
			then
				echo -e " $RED[${line:10}]$NC"
			else
				echo
				echo "$indent$line"
			fi
			state=1
		else
			if [[ "$line" =~ ^Your\ branch\ is\ up\ to\ date\ with ]]
			then
				:
			elif [[ "$line" =~ ^nothing\ to\ commit ]]
			then
				:
			elif [[ "$line" =~ ^Changes\ not\ staged\ for\ commit ]]
			then
				state=101
			elif [[ "$line" =~ ^Untracked\ files ]]
			then
				state=102
			#else
			#	echo "			|$indent$line"
			fi
		fi

		if [ $state == 101 ]
		then
			echo "${indent}Изменения, не включённые в коммит:"
			state=201
		elif [ $state == 201 ]
		then
			if [[ $line =~ ^\(use\  ]]
			then
				:
			else
				echo -e "$indent$RED$line$NC"
			fi
		elif [ $state == 102 ]
		then
			echo "${indent}Файлы, не попавшие под контроль версий:"
			state=202
		elif [ $state == 202 ]
		then
			if [[ $line =~ ^\(use\  ]]
			then
				:
			else
				echo -e "$indent$RED$line$NC"
			fi
		fi





		#showGitStatusLine "$i" "$line"
		#echo "-- $argSubroot -- $line"
		:||'
		if [ $state == 0 ]
		then
			if [[ "$line" =~ ^On\ branch ]]
			then
				echo "ON BRANCH \"${line:10}\""
				state=1
			else
				echo ":] state 0: неожиданная строка: \"$line\""
			fi
		elif [ $state == 1 ]
		then
			if [[ "$line" =~ ^Your\ branch\ is\ up\ to\ date\ with ]]
			then
				echo "UP-TO-DATE CONFIRMED (synchronized)"
			else
				echo "$state%%%$line"
			fi
			state=2
		elif [ $state == 2 ]
		then
			#echo "$indent$line"

			if [[ "$line" =~ ^Changes\ not\ staged\ for\ commit ]]
			then
				echo "${indent}Изменения, не включённые в коммит:"
				state=3
			else
				echo "$state%%%$line"
			fi
		elif [ $state == 3 ]
		then
			if [[ "$line" =~ ^modified: ]]
			then
				echo "${indent}    Изменено: ${line:9}"
			elif [[ "$line" =~ ^Untracked\ files: ]]
			then
				echo "${indent}Файлы, не попавшие под контроль версий:"
				state=4
			else
				echo "$state%%%$line"
			fi
		elif [ $state == 4 ]
		then
			if [[ "$line" =~ use\ add\	]]
			then
				:
			elif [ -z "$line" ]
			then
				state=2
			else
				echo "$indent$line" # line уже с отступом
			fi
		else
			echo "$state---$line"
		fi
'
	done < <(git status )
}

function gitStatus {
	local curDir=$(pwd)
	local state
	local i
	local tmp
	for ((iLevel = 0 ; iLevel <= 100 ; ++iLevel))
	do
		#echo ":: $iLevel"
		if [ $iLevel -eq 100 ]
		then
			ERROR 'корневой репозиторий git не найден'
		fi
		if [ -d .git ]
		then
			git status
			state=hash
			for i in $(git submodule status --recursive)
			do
				if [ $state == hash ]
				then
					state=dir
				elif [ $state == dir ]
				then
					tmp=$PWD
					pushd $i > /dev/null
						showGitStatusPart "$tmp" "$i"
					popd > /dev/null
					state=head
				elif [ $state == head ]
				then
					state=hash
				fi
			done

			#while read line
			#do
			#	echo $line
			#done < <(git submodule status --recursive)
			return 0
		else
			pushd .. > /dev/null
		fi
	done

	ERROR 'not implemented'
}

function gitStatus2 {
	local -a stack=( "#" $PWD ) # Здесь храним тройки (отступ; директория)
	local indent parent
	local state
	local -i counter=0
	while [ ${#stack[@]} -gt 0 ]
	do
		if ((++counter > 10))
		then
			echo 'Зацикливание предотвращено'
			break
		fi
		parent="${stack[0]}"
		state=indent
		for i in ${stack[@]}
		do
			if [ $state == indent ]
			then
				indent=$i
				state=parent
			elif [ $state == parent ]
			then
				parent=$i
				state=finished
			fi
		done
		stack=( "${stack[@]:1}" )
		#echo "oooooooooo ${stack[@]}" #
		echo "${indent}show git status for \"$parent\""
		# добавляем дочерние элементы в стек
		state=hash
		pushd $parent > /dev/null
			for i in $(git submodule status)
			do
				if [ $state == hash ]
				then
					state=dir
				elif [ $state == dir ]
				then
					#echo "%%: $i"
					stack=( "$indent#### $parent/$i" "${stack[@]}" )
					state=head
				elif [ $state == head ]
				then
					state=hash
				fi
			done
		popd > /dev/null # boris here
		#echo "tttttttttt ${stack[@]}" #
		#for ii in "${stack[@]}"
		#do
		#	echo "[$ii]"
		#done
		#break #
		#echo '=================='
	done
}

for iArg in "$@"
do
	echo "[$iArg]"
	if [ $state == initial ]
	then
		if [ "$iArg" == status ]
		then
			gitStatus2
			exit 0
		fi
		if [ "$iArg" == task ]
		then
			echo -n
			#
		fi
	fi
done

if [ $state == initial ]
then
	gitStatus2
fi
