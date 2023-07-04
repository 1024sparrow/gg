#!/bin/bash

declare iArg state=initial
declare -a gitArguments

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
		exit 0
	fi
done

function gitStatus {
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
