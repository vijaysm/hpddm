#! /bin/bash

#
#  This file is part of HPDDM.
#
#  Author(s): Pierre Jolivet <pierre.jolivet@enseeiht.fr>
#       Date: 2015-12-14
#
#  Copyright (C) 2015      Eidgenössische Technische Hochschule Zürich
#                2016-     Centre National de la Recherche Scientifique
#
#  HPDDM is free software: you can redistribute it and/or modify
#  it under the terms of the GNU Lesser General Public License as published
#  by the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  HPDDM is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU Lesser General Public License for more details.
#
#  You should have received a copy of the GNU Lesser General Public License
#  along with HPDDM.  If not, see <http://www.gnu.org/licenses/>.
#

# https://github.com/fearside/ProgressBar/
function ProgressBar {
    let _progress=(${1}*100/${2}*100)/100
    let _done=(${_progress}*4)/10
    let _left=40-$_done

    _fill=$(printf "%${_done}s")
    _empty=$(printf "%${_left}s")
    printf "\r[ ${_fill// /#}${_empty// /-} ] ${_progress}%% ${3}"
}

TMPFILE=$(mktemp /tmp/hpddm-payload.XXXXXX)
START=$SECONDS
make clean > /dev/null
I=0
for CXX in g++ clang++
do
    if [ "$CXX" == "g++" ]; then
        export OMPI_CC=gcc
        export MPICH_CC=gcc
        export OMPI_CXX=g++
        export MPICH_CXX=g++
    else
        export OMPI_CC=clang
        export MPICH_CC=clang
        export OMPI_CXX=clang++
        export MPICH_CXX=clang++
    fi
    for N in C F
    do
        for OTHER in "" "-DFORCE_COMPLEX" "-DGENERAL_CO" "-DFORCE_SINGLE" "-DFORCE_SINGLE -DFORCE_COMPLEX"
        do
            ProgressBar $I 60 "make -j4 HPDDMFLAGS=\"-DHPDDM_NUMBERING=\\\'$N\\\' $OTHER\" CXX=$CXX"
            make -j4 HPDDMFLAGS="-DHPDDM_NUMBERING=\'$N\' $OTHER" 1> /dev/null 2>$TMPFILE
            if [ $? -ne 0 ]; then
                echo -e "\n[ \033[91;1mFAIL\033[0m ]"
                cat $TMPFILE
                unlink $TMPFILE
                exit 1
            fi
            I=$((I + 1))
            if  [[ (! "$CXX" == "g++" || ! "$OSTYPE" == darwin*) ]];
            then
                ProgressBar $I 60 "make test HPDDMFLAGS=\"-DHPDDM_NUMBERING=\\\'$N\\\' $OTHER\" CXX=$CXX"
                if [[ ("$OTHER" == "" || "$OTHER" == "-DFORCE_COMPLEX" || "$OTHER" == "-DGENERAL_CO" || ! "$OSTYPE" == darwin*) ]];
                then
                    make test 1> $TMPFILE 2>&1
                elif [[ "$OSTYPE" == darwin* ]];
                then
                    make test_cpp test_c 1> $TMPFILE 2>&1
                fi
                if [ $? -ne 0 ]; then
                    echo -e "\n[ \033[91;1mFAIL\033[0m ]"
                    cat $TMPFILE
                    unlink $TMPFILE
                    exit 1
                fi
            fi
            I=$((I + 1))
            ProgressBar $I 60 "                                                                                         "
            make clean > /dev/null
            I=$((I + 1))
            ProgressBar $I 60 "                                                                                         "
        done
    done
done
echo -e "\n[ \033[92;1mOK\033[0m ] ($((SECONDS - START)) seconds)"
unlink $TMPFILE
