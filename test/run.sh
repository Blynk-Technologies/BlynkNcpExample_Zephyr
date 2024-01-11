#!/bin/env bash

# Copyright (c) 2024 Blynk Technologies Inc.
#
# SPDX-License-Identifier: Apache-2.0
set -e

function cleanup {
    #collect build artifacts
    mv ${TMPDIR}/build.log ${PRJDIR}/${SAMPLE_PATH}/build/ &>> /dev/null
    tarname=build_${BOARD}_${SRC_VERSION}_[$(date -u +%s)].tar.gz
    mkdir -p ${ARTIFACTS_PATH} &>> /dev/null
    cd ${PRJDIR}/${SAMPLE_PATH} &>> /dev/null
    tar -pczf ${ARTIFACTS_PATH}/${tarname} build/ &>> /dev/null
    cd - &>> /dev/null
    #TODO: push to cloud

    # cleanup
    cd ${orig_path}
    rm -rf ${TMPDIR}
}

trap cleanup EXIT

orig_path=${PWD}
script_dir=$(readlink -f $0 | xargs dirname)
export script_name=$(readlink -f $0 | xargs basename)

if [ "$#" -ne 1 ]; then
    echo "syntax: ${script_name} <board>"
    echo ""
    echo "available boards:"
    cd ${script_dir}/boards/
    ls -d */ | sed 's|/||g'
    cd - &>> /dev/null
    exit 0
fi

export BOARD=${1}

#configuration
if [ -z ${CONF_FILE+x} ]
then
    source ${script_dir}/config
else
    source ${CONF_FILE}
fi

if [ -z ${CRED_FILE+x} ]
then
    source ${script_dir}/.credentials
else
    source ${CRED_FILE}
fi

export TMPDIR=$(mktemp -d)
export PRJDIR=${TMPDIR}/BlynkNcpExample_Zephyr

start_time=$(date -u +%s)
echo "start time [UTC] is ${start_time}" | tee -api ${TMPDIR}/build.log

#clone
echo "clone repo" | tee -api ${TMPDIR}/build.log
cd ${TMPDIR}
git clone git@github.com:Blynk-Technologies/BlynkNcpExample_Zephyr.git &>> ${TMPDIR}/build.log
cd BlynkNcpExample_Zephyr
git submodule update --init --recursive &>> ${TMPDIR}/build.log
echo "clone repo done" | tee -api ${TMPDIR}/build.log

echo "git commit:"
git log --oneline -1 | tee -api ${TMPDIR}/build.log
echo ""

echo "git submodules:"
git submodule status | tee -api ${TMPDIR}/build.log
echo ""

echo "zephyr ver:"
cat ${ZEPHYR_BASE}/VERSION | tee -api ${TMPDIR}/build.log
echo ""

SRC_VERSION=$(cat ${PRJDIR}/${SAMPLE_PATH}/prj.conf | grep CONFIG_MCUBOOT_IMGTOOL_SIGN_VERSION | sed 's|^.*=||' | sed 's|"||g')
echo "fw ver: ${SRC_VERSION}"
echo ""

tests=($(${script_dir}/boards/${BOARD}/supported_tests))

for test in ${tests[@]}
do
    echo "START TEST [${test}]" | tee -api ${TMPDIR}/build.log
    if ${script_dir}/tests/${test} &>> ${TMPDIR}/build.log
    then
        echo "TEST [${test}] OK" | tee -api ${TMPDIR}/build.log
    else
        echo "TEST [${test}] FAIL" | tee -api ${TMPDIR}/build.log
        test_fail="1"
    fi
done

end_time=$(date -u +%s)
echo '===========================================================' | tee -api ${TMPDIR}/build.log
if [ -z ${test_fail+x} ]
then
    echo '===============ALL TESTS ARE OK============================' | tee -api ${TMPDIR}/build.log
else
    echo '================SOME TESTS ARE FAIL========================' | tee -api ${TMPDIR}/build.log
fi
echo "===============TOOK $((end_time-start_time)) SECONDS============================" | tee -api ${TMPDIR}/build.log
echo '===========================================================' | tee -api ${TMPDIR}/build.log

exit 0
