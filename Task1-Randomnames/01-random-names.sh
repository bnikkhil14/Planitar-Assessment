#!/bin/bash
#author:Nikhil
_URL=https://reqres.in/api/users?page=1
val_arr=()

for i in  `curl -s -k $_URL | jq -r '.data[] as $k | "\($k.first_name),\($k.last_name)"'`
do
	val_arr+="$i;"
done

shuffle_str=`echo ${val_arr[@]} | sed -r 's/(.[^;]*;)/ \1 /g' | tr " " "\n" | shuf | tr -d "\n"`

IFS=';'
for i in $shuffle_str
do
	echo $(echo $i | tr ',' ' ')
done
