#!/bin/bash
# ********************************************************************
# Ericsson Radio Systems AB                                     SCRIPT
# ********************************************************************
#
#
# (c) Ericsson Radio Systems AB 2018 - All rights reserved.
#
# The copyright to the computer program(s) herein is the property
# of Ericsson Radio Systems AB, Sweden. The programs may be used 
# and/or copied only with the written permission from Ericsson Radio 
# Systems AB or in accordance with the terms and conditions stipulated 
# in the agreement/contract under which the program(s) have been 
# supplied.
#
# ********************************************************************
# Name    : install_environment.sh
# Date    : 13/07/2020(dummy date) Last modified 25/04/2023
# Purpose : Ericsson Network IQ Installation environment check and install
#           script
# Usage   : install_environment.sh [-v] SRC_FILE INI_FILE
# ********************************************************************

#Checks specified directory
checkdir() {
  if [ -d $1 -a -O $1 -a -r $1 -a -x $1 -a -w $1 ] ; then
    if [ $VERBOSE = 1 ] ; then
      echo "Directory $1 is OK" | tee -a ${LOGFILE}
    fi
  else
    echo "ERROR: User has no full control to directory $1" | tee -a ${LOGFILE}
    FAIL=1
  fi
}

############## THE SCRIPT BEGINS HERE ##############

VERBOSE=0
FAIL=0

if [ -z "${CONF_DIR}" ] ; then
  echo "CONF_DIR must be specified"
  exit 100
fi

SRC_FILE=${CONF_DIR}/niq.rc
INI_FILE=${CONF_DIR}/niq.ini

if [ "$1" = "-v" ] ; then
  VERBOSE=1
fi

if [ -r ${SRC_FILE} ] ; then
  . ${SRC_FILE}
else
  echo "ERROR: Can't use SRC_FILE \"$SRC_FILE\""
  exit 127
fi

if [ -d ${LOG_DIR} -a -O ${LOG_DIR} -a -r ${LOG_DIR} -a -x ${LOG_DIR} -a -w ${LOG_DIR} ] ; then
  if [ ! -d ${LOG_DIR}/platform_installer ] ; then
    mkdir ${LOG_DIR}/platform_installer
  fi
else
  echo "Log directory does not exist"
  exit 99
fi

TIMESTAMP=`date +%d.%m.%y_%H:%M:%S`

LOGFILE=${LOG_DIR}/platform_installer/pre_runtime_${TIMESTAMP}.log


if [ ! -r ${INI_FILE} ] ; then
  echo "ERROR: Can't read INI_FILE \"$INI_FILE\"" | tee -a ${LOGFILE}
  exit 126
fi

## SRC_FILE SOURCED

if [ ${VERBOSE} = 1 ] ; then
  echo "Checking username... ${LOGNAME}" | tee -a ${LOGFILE}
fi

if [ ${LOGNAME} != "${SYS_USER}" ] ; then
  echo "ERROR: Installation have to be executed by ${SYS_USER}" | tee -a ${LOGFILE}
  exit 1
fi

### USER IS OK

OSTYPE=`uname -s`
OSLEVEL=`uname -r`
if [ -f /etc/redhat-release ] ; then 
OSLEVEL_RHEL=`/usr/bin/head -1 /etc/redhat-release | cut -d ' ' -f 7`
fi

if [ ${VERBOSE} = 1 ] ; then
  echo "Checking OS... ${OSTYPE} ${OSLEVEL}" | tee -a ${LOGFILE}
fi

echo "Environment is ${OSTYPE} with version ${OSLEVEL_RHEL}" | tee -a ${LOGFILE}

### OPERATING SYSTEM IS OK

checkdir ${DATA_DIR}
checkdir ${PMDATA_DIR}
checkdir ${PMDATA_SOEM_DIR}
checkdir ${ETLDATA_DIR}
checkdir ${ARCHIVE_DIR}
checkdir ${LOG_DIR}
checkdir ${REJECTED_DIR}
checkdir ${REFERENCE_DIR}
checkdir ${DWH_DIR}
checkdir ${REP_DIR}
checkdir ${BIN_DIR}
checkdir ${CONF_DIR}
checkdir ${INSTALLER_DIR}
checkdir ${PLATFORM_DIR}
checkdir ${IQ_DIR}
checkdir ${RT_DIR}
checkdir ${ADMIN_BIN}

if [ ${FAIL} = 1 ] ; then
  echo "Environment installation failed" | tee -a ${LOGFILE}
  exit 10
else
  if [ ${VERBOSE} = 1 ] ; then
    echo "Installation environment checked" | tee -a ${LOGFILE}
  fi
fi

if [ ${VERBOSE} = 1 ] ; then
  echo "Environment installation successfully performed" | tee -a ${LOGFILE}
fi

