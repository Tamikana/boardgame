#!/bin/sh

confPath=$1

if [ -z "$confPath" ]; then
  confPath="./config.yml"
fi

command="stack exec boardgame-server"

if [ -f ${confPath} ]; then 
  command="${command} ${confPath}"
fi

echo "${command}"

$command


