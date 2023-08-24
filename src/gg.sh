#!/bin/bash

# boris here:
# - HEAD detached from
# - Your branch is ahead of 'origin/develop-v1.0.gg-3-status' by 1 commit (пометка при указании пути до подмодуля
# - относительные пути до подмодулей)

declare i iArg state=initial
declare -a gitArguments
readonly THIS=$PWD

function ERROR {
	echo $1 >& 2
	exit 1
}

RED='\e[0;31m'
GREEN='\e[0;32m'
YELLOW='\e[0;33m'
BLUE='\e[0;36m'
PINK='\e[0;35m'
#YELLOW='\e[0;33m\e[41m'  # на красном фоне
#UNDERLINE='\e[5;31m'
UNDERLINE='\e[4;31m'
NC='\033[0m' # No Color

COL_SUBMODULE='\e[4;37m'
COL_LOCALROOT='\e[2;37m'

function fTest {
	for i in node git
	do
		if ! which $i > /dev/null
		then
			ERROR "Для работы утилиты необходимо установить в систему утилиту \"$i\""
		fi
	done
}

function relative {
	local argPath=$1
	local retVal=$(node -e "process.stdout.write(require('path').relative('$THIS', '$argPath'));")
# boris here: / после . и ..
	if [ -z "$retVal" ]
	then
		echo ./
	else
		echo "$retVal/"
	fi
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

[ -z "$(which node)" ] && ERROR 'Для работы утилиты необходимо наличие в системе nodejs (команда "node")'

function showGitStatusPart {
	local state=0
	# parent доступен из родительской функции...
	local indent="$2"
	local color=$PINK # it is INVALID color
	local localRoot=$(relative $parent)

	:||'
States:
0 - initial
1 - branch taken
2 - up-to-date confirmed
3 - not staged for commit
4 - untracked files
'

	#echo -en "${strIndent}${YELLOW}show git status for \"$parent\"${NC}"
	echo -en "${strIndent}${COL_SUBMODULE}${localRoot:0:-1}${NC}"
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
				echo -e " $BLUE[${line:10}]$NC :"
			else
				echo -e " :"
				echo "$indent$line"
			fi
			state=1
		elif [ -z "$line" ]
		then
			state=1
		elif [ "${state:1:1}" == 0 ]
		then
			:
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
			elif [[ "$line" =~ ^Changes\ to\ be\ committed ]]
			then
				state=103
			elif [[ "$line" =~ ^no\ changes\ added\ to\ commit ]]
			then
				:
			else
				echo "			|$indent$line"
			fi
		fi

		if [ $state == 101 ]
		then
			echo "${indent}  Изменения, не включённые в коммит:"
			color=$RED
			state=201
		elif [ $state == 201 ]
		then
			#color=$RED
			if [[ $line =~ ^\( ]]
			then
				:
			elif [[ $line =~ ^modified: ]]
			then
				if [[ $line =~ \(new\ commits,\ modified\ content\)$ ]]
				then
					echo -e "$indent	${color}Изменено:       $COL_LOCALROOT$localRoot${UNDERLINE}${line:12: -32}$NC$color (ссылка смещена, да и содержимое поменялось...)$NC"
				elif [[ $line =~ \(new\ commits\)$ ]]
				then
					echo -e "$indent	${color}Изменено:       $COL_LOCALROOT$localRoot${UNDERLINE}${line:12: -23}$NC$color (ссылка смещена)$NC"
				elif [[ $line =~ \(modified\ content\)$ ]]
				then
					echo -e "$indent	${color}Изменено:       $COL_LOCALROOT$localRoot${UNDERLINE}${line:12: -19}$NC$color (содержимое поменялось...)$NC"
				else
					echo -e "$indent	${color}Изменено:       $COL_LOCALROOT$localRoot$color${line:12}$NC"
				fi
			elif [[ $line =~ ^typechange: ]]
			then
					echo -e "$indent	${color}Изм.права:      $COL_LOCALROOT$localRoot$color${line:12}$NC"
			elif [[ $line =~ ^deleted: ]]
			then
					echo -e "$indent	${color}Удалено:        $COL_LOCALROOT$localRoot$color${line:12}$NC"
			elif [[ $line =~ ^new\ file: ]]
			then
					echo -e "$indent	${color}Новый файл:     $COL_LOCALROOT$localRoot$color${line:12}$NC"
			elif [[ $line =~ ^renamed: ]]
			then
					echo -e "$indent	${color}Переименовано:  $COL_LOCALROOT$localRoot$color${line:12}$NC"
			else
				echo -e "$indent##$RED$line$NC"
			fi
		elif [ $state == 102 ]
		then
			echo "${indent}  Файлы, не попавшие под контроль версий:"
			color=$BLUE
			state=202
		elif [ $state == 202 ]
		then
			if [[ $line =~ ^\(use\  ]]
			then
				:
			else
				echo -e "$indent	$COL_LOCALROOT$localRoot$RED$line$NC"
			fi
		elif [ $state == 103 ]
		then
			echo "${indent}  Добавлены в грядущий коммит:"
			color=$GREEN
			state=201
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
	echo
}

function gitStatus {
	local -a stack # Здесь храним тройки (отступ; директория)
	local -i indent
	local strIndent
	local parent
	local state
	local -i counter=0
	local root=$PWD
	local i
	for ((i = 0 ; i < 100 ; ++i))
	do
		if [ -d .git ]
		then
			stack=( "0 $PWD" )
			while [ ${#stack[@]} -gt 0 ]
			do
				if ((++counter > 10))
				then
					echo 'Зацикливание предотвращено'
					break
				fi
				parent="${stack[0]}"
				stack=( "${stack[@]:1}" )
				state=indent
				for i in $parent
				do
					#echo "[$i]"
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
				strIndent=
				for ((i=0;i<$indent;++i))
				do
					strIndent="$strIndent    "
				done
				pushd $parent > /dev/null
					showGitStatusPart $parent "$strIndent"
				popd > /dev/null
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
							stack=( "$((indent+1)) $parent/$i" "${stack[@]}" )
							state=head
						elif [ $state == head ]
						then
							state=hash
						fi
					done
				popd > /dev/null
			done
			break
		else
			pushd ..
		fi
	done
}

for iArg in "$@"
do
	echo "[$iArg]"
	if [ $state == initial ]
	then
		if [ "$iArg" == status ]
		then
			gitStatus
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
	gitStatus
fi
