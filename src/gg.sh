#!/bin/bash

declare i iArg state=initial
declare -a gitArguments

function ERROR {
	echo $1 >& 2
	exit 1
}

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

function gitStatus {
	local curDir=$(pwd)
	local state
	local i
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
					echo "
------- $i -------
"
					pushd $i > /dev/null
						git status
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
	fi
done
