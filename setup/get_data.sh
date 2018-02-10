#!/bin/bash

data_dir=""
pwdbase=`basename $PWD`
if [ $pwdbase == "setup" ]; then
    data_dir="../data"
elif [ -d "setup" ]; then
    data_dir="data"
fi

mkdir -p $data_dir

#echo -n "Kaggle username: "
#read username
#echo -n "Kaggle password: "
#read -s password
#echo

kg download -u localmaxima -p isnotsofaraway -c "hillary-clinton-emails" -v
