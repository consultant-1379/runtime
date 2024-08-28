#!/usr/bin/bash
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
# Name    : change_eniq_security.sh
# Date    : 10/07/2020(dummy date) Last modifies 25/04/2023
# Purpose : Ericsson Network IQ ETLC engine control script
# Usage   : change_eniq_security.sh <web_module_name> disable|enable|status"
# ********************************************************************

if [ ! -r "${BIN_DIR}/common_variables.lib" ] ; then
  echo "ERROR: Source file is not readable at ${BIN_DIR}/common_variables.lib"
  exit 6
fi

. ${BIN_DIR}/common_variables.lib

checkFilePresence(){
	IS_FILE_PRESENT=0
	fileName=$1
	if [ -r $fileName ]
	then
		IS_FILE_PRESENT=`$EXPR $IS_FILE_PRESENT + 1`
	else
		IS_FILE_PRESENT=`$EXPR $IS_FILE_PRESENT + 0`
	fi
}


remove_lock_file(){
	if [ -f $LOCK_FILE ]
        then
                log "Removing Log File before exiting: $LOCK_FILE "
                $RM -rf $LOCK_FILE 2>&1 > /dev/null
        fi
}


error_exit(){
	errStr=$1
	dTime=`$DATE +'%m/%d/%Y %H:%M:%S'`
	term=`$WHO | $NAWK  -F' ' '{print $2}'`
	$ECHO " $dTime :: $term :: Error: $errStr " >> $HTTP_LOG_FILE
	$ECHO " Error: $errStr !!!!Exiting script.... "
	remove_lock_file
	$RM -rf $TEMP_FILE* 2>&1 > /dev/null
	$RM -rf $WEBXML_FILE.backup 2>&1 > /dev/null
	$RM -rf $INDEX_HTML.backup 2>&1 > /dev/null
	$RM -rf $APP_JNLP.backup 2>&1 > /dev/null
	$RM -rf $APP_JNLP_TEMPLATE.backup 2>&1 > /dev/null
	exit 2
}

log(){
	mess=$1
	dTime=`$DATE +'%m/%d/%Y %H:%M:%S'`
	term=`$WHO | $NAWK  -F' ' '{print $2}'`
	$ECHO " $dTime :: $term :: $mess " >> $HTTP_LOG_FILE
	#$ECHO " $mess "
}


checkDirPresence(){
	IS_DIR_PRESENT=0
	dir=$1
	if [ -d $dir ]
	then
		IS_DIR_PRESENT=`$EXPR $IS_DIR_PRESENT + 1`
	else
		IS_DIR_PRESENT=`$EXPR $IS_DIR_PRESENT + 0`
	fi
}

copyAndDelTempFile(){
log " Replacement was successfull. Created the TMP_FILE: $1 with the changes. "
log " Copying the TEMP_FILE: $1 to ORIG FILE: $2"
$CP $1 $2
log " Copied successfully. "
if [ -f $1 ]
then
	log " Removing the TEMP_FILE: $1 "
	$RM -rf $1 2>&1 > /dev/null
	log " Removed successfully."
fi
}

execCommand(){
$SED $1 < $2 > $3
status=`$ECHO $?`
if [ $status -eq 0 ]
then
	copyAndDelTempFile $3 $2
else
revert_back $2
error_exit "Error occur while enabling security in file : $2" 
fi
}	

http_enable(){
	log " Going to enable the security from HTTP to HTTPS. "
	IS_STATE_CHANGED=0
	if [ $IS_ALREADY_RUNNING -eq 1 ]
        then
                $ECHO "One instance of this process is already running. Can not continue..."
                exit 3
    fi
	http_status_inner
	if [ $IS_HTTPS_ENABLED -eq 0 ]
	then
		take_backup $WEBXML_FILE
		execCommand 's/NONE/CONFIDENTIAL/g' $WEBXML_FILE $TEMP_FILE
		if [ -f $INDEX_HTML ]
		then
			take_backup $INDEX_HTML
			execCommand 's/http/https/g' $INDEX_HTML $TEMP_FILE_INDEX
			execCommand 's/8080/8443/g' $INDEX_HTML $TEMP_FILE_INDEX 
		fi
		if [ -f $APP_JNLP ]
		then
			take_backup $APP_JNLP
			execCommand 's/http/https/g' $APP_JNLP $TEMP_FILE_JNLP
			execCommand 's/8080/8443/g' $APP_JNLP $TEMP_FILE_JNLP
		fi
		if [ -f $APP_JNLP_TEMPLATE ]
        then
            take_backup $APP_JNLP_TEMPLATE
            execCommand 's/http/https/g' $APP_JNLP_TEMPLATE $TEMP_FILE_JNLP_TEMPLATE
            execCommand 's/8080/8443/g' $APP_JNLP_TEMPLATE $TEMP_FILE_JNLP_TEMPLATE
        fi
		IS_STATE_CHANGED=`$EXPR $IS_STATE_CHANGED + 1`
	else
		$ECHO " Security is already enabled. "
		IS_STATE_CHANGED=`$EXPR $IS_STATE_CHANGED + 0`
	fi
}

http_disable() {
	IS_STATE_CHANGED=0
	log " Going to disable the security from HTTPS to HTTP. "
	if [ $IS_ALREADY_RUNNING -eq 1 ]
	then
		$ECHO "One instance of this process is already running. Can not continue..."
        	exit 3
	fi
	http_status_inner
	if [ $IS_HTTPS_ENABLED -eq 1 ]
	then
		take_backup $WEBXML_FILE
     	execCommand 's/CONFIDENTIAL/NONE/g' $WEBXML_FILE $TEMP_FILE
		if [ -f $INDEX_HTML ]
		then
			take_backup $INDEX_HTML
            execCommand 's/https/http/g' $INDEX_HTML $TEMP_FILE_INDEX
            execCommand 's/8443/8080/g' $INDEX_HTML $TEMP_FILE_INDEX
        fi
        if [ -f $APP_JNLP ]
        then
			take_backup $APP_JNLP
            execCommand 's/https/http/g' $APP_JNLP $TEMP_FILE_JNLP
            execCommand 's/8443/8080/g' $APP_JNLP $TEMP_FILE_JNLP
        fi
        if [ -f $APP_JNLP_TEMPLATE ]
        then
            take_backup $APP_JNLP_TEMPLATE
            execCommand 's/https/http/g' $APP_JNLP_TEMPLATE $TEMP_FILE_JNLP_TEMPLATE
            execCommand 's/8443/8080/g' $APP_JNLP_TEMPLATE $TEMP_FILE_JNLP_TEMPLATE
        fi
        IS_STATE_CHANGED=`$EXPR $IS_STATE_CHANGED + 1`
	else
		$ECHO " Security is already disabled. "
		IS_STATE_CHANGED=`$EXPR $IS_STATE_CHANGED + 0`
	fi
}


take_backup(){
	log "Taking backup"
	$CP $1 $1.backup 2>&1 > /dev/null
	status_02=`$ECHO $?`
	if [ $status_02 -eq 0 ]
	then
		log " Backup of original files has been taken. $1 ==> $1.backup "
		$ECHO " Backup of oiginal files has been taken. "
	else
		$ECHO " Error : Failed to take the backup of original files. "
		log " Error: : Failed to take the backup. $1 ==> $1.backup "
		error_exit " Failed to take the backup.   $1 ==> $1.backup "
	fi
}


revert_back(){
	if [ -f $1.backup ]
	then
		$CP $1.backup $1 2>&1 > /dev/null
	fi
	status_02=`$ECHO $?`
	if [ $status_02 -eq 0 ]
    then
			log " Reverting back original files. $1.backup ==> $1 "
			$ECHO " Reverting back original files. "
	else
		$ECHO " Error : Failed to revert back the original files. "
		log " Error : Failed to revert back the original files. $1.backup ==> $1 "
        fi
}


http_status_inner(){
	log " Going to check Status of Security. "
        IS_HTTPS_ENABLED=0
        isEnable=`$CAT $WEBXML_FILE | $GREP CONFIDENTIAL | $WC -l`
        if [ $isEnable -ge 1 ]
        then
                IS_HTTPS_ENABLED=`$EXPR $IS_HTTPS_ENABLED + 1`
                log " Security is enabled. HTTPS will be used by default. "
        else
                IS_HTTPS_ENABLED=`$EXPR $IS_HTTPS_ENABLED + 0`
                log " Security is disabled. HTTP will be used by default. "
        fi
}

http_status(){
	log " Going to check Status of Security. "
	IS_HTTPS_ENABLED=0
	isEnable=`$CAT $WEBXML_FILE | $GREP CONFIDENTIAL | $WC -l`
	if [ $isEnable -ge 1 ]
	then
		IS_HTTPS_ENABLED=`$EXPR $IS_HTTPS_ENABLED + 1`
		log " Security is enabled. HTTPS will be used by default. "
		$ECHO " Security is enabled. HTTPS will be used by default. "
	else
		IS_HTTPS_ENABLED=`$EXPR $IS_HTTPS_ENABLED + 0`
		log " Security is disabled. HTTP will be used by default. "
		$ECHO  " Security is disabled. HTTP will be used by default. "
	fi
}

start_webserver() {

   $ECHO " Starting webserver "
   log "  Starting webserver "
   $WEBSERVER_COMMAND_FILE start
   output=`$ECHO $?`
   if [ $output -eq 0 ]
   then 
         $ECHO " Successfully started webserver "
         log " Successfully started webserver " 
   else 
         $ECHO " Can not start webserver....Check webserver logs for more details or contact SYSTEM ADMIN...."
         log " Error : Can not start webserver....Check webserver logs for more details or contact SYSTEM ADMIN...."
   fi
}

stop_webserver() {

   $ECHO " Stopping webserver "
   log " Stopping webserver "
   $WEBSERVER_COMMAND_FILE stop
   output=`$ECHO $?`
   if [ $output -eq 0 ]
   then 
         $ECHO " Successfully stopped webserver "
         log " Successfully stopped webserver "
   else 
         $ECHO " Can not stop webserver....Check webserver logs for more details or contact  SYSTEM ADMIN...." 
         log " Error : Can not stop webserver....Check webserver logs for more details or contact SYSTEM ADMIN...."
   fi
}


handleLogFiles(){
	log " Handling Log Files. "
	if [ $IS_ALREADY_RUNNING -eq 1 ]
        then
                $ECHO "One instance of this process is already running. Can not continue..."
                exit 3
        fi
	if [ -f $HTTP_LOG_FILE ]
	then
		dTime=`$DATE +'%m_%d_%Y_%H::%M::%S'`
		getSize=`$LS -lrt $HTTP_LOG_FILE | $NAWK -F' ' '{print $5}'`
		getSize=`$EXPR $getSize + 0`
		if [ $getSize -gt 1048576 ] 
		then
			zip -9 ${HTTP_LOG_FILE}.${dTime}.zip ${HTTP_LOG_FILE} 2>&1 > /dev/null
			status=`$ECHO $?`
			if [ $status -eq 0 ]
			then
				log " Took backup of log file : $HTTP_LOG_FILE to file: ${HTTP_LOG_FILE}.${dTime}.zip "
				$ECHO " " > $HTTP_LOG_FILE
			else
				log " Error : Error comes while taking backup of file : $HTTP_LOG_FILE "
			fi	
		fi
	fi

	#Delete older zip  files
	checkList=`$LS $HTTP_LOG_DIR | $GREP -i zip |  $WC -l`
	checkList=`$EXPR $checkList + 0`
	if [ $checkList -gt 0 ]
	then
		find $HTTP_LOG_FILE*.zip -mtime +3 -exec $RM -rf {} \; 2>&1 > /dev/null
	fi
}


############################
###Main work starts here
############################

###
# Global Variables
###
WEBXML_FILE="/eniq/sw/runtime/tomcat/webapps/$1/WEB-INF/web.xml"
INDEX_HTML="/eniq/sw/runtime/tomcat/webapps/$1/index.html"
APP_JNLP="/eniq/sw/runtime/tomcat/webapps/$1/$1.jnlp"
APP_JNLP_TEMPLATE="/eniq/sw/runtime/tomcat/webapps/$1/$1.jnlp.template"
TEMP_FILE='/eniq/sw/installer/.httptemp.xml'
TEMP_FILE_INDEX='/eniq/sw/installer/.httpindex.html'
TEMP_FILE_JNLP='/eniq/sw/installer/.httpjnlp.html'
TEMP_FILE_JNLP_TEMPLATE='/eniq/sw/installer/.httpjnlptemplate.html'
LOCK_FILE='/eniq/sw/installer/.httplock.tmp'
HTTP_LOG_FILE='/eniq/log/sw_log/eniq_http/http.log'
HTTP_LOG_DIR='/eniq/log/sw_log/eniq_http'
WEBSERVER_COMMAND_FILE='/eniq/sw/bin/webserver'
IS_FILE_PRESENT=0
IS_DIR_PRESENT=0
IS_HTTPS_ENABLED=0
IS_STATE_CHANGED=0
IS_ALREADY_RUNNING=0

###
#Starting main functionality
###

#####
##Delete temp files, if any
####
$RM -rf $TEMP_FILE* 2>&1 > /dev/null

######
## Check User. Only dcuser should be allowed to run the script
#####
isDCUSER=`$ID | $NAWK -F' ' '{print $1}' | $GREP -i dcuser | $WC -l`
isDCUSER=`$EXPR $isDCUSER + 0`
if [ $isDCUSER -ne 1 ]
then
	$ECHO " This script can be run only as dcuser. "
	exit 5
fi

#####
##Check Arguments
#####
if [ $# -ne 2 ]
then
        $ECHO "Usage: change_eniq_security.sh <web_module_name> disable|enable|status "
        exit 4
fi


####
## Check if LOG_DIR exist otherwise create it
####
checkDirPresence $HTTP_LOG_DIR
if [ $IS_DIR_PRESENT -eq 0 ]
then
	$MKDIR -m 777 -p $HTTP_LOG_DIR
fi

#####
## Check if already running
#####
checkFilePresence $LOCK_FILE
if [ -f $LOCK_FILE ]
then
	IS_ALREADY_RUNNING=`$EXPR $IS_ALREADY_RUNNING + 1`
else
        $TOUCH $LOCK_FILE
        log "Created log file: $LOCK_FILE to know the running instance of this script."
fi


######
##Handling Log files
######
handleLogFiles

###
## Check if webserver file present otherwise exit
###
checkFilePresence $WEBSERVER_COMMAND_FILE
if [ $IS_FILE_PRESENT -eq 0 ]
then
	error_exit "File: $WEBSERVER_COMMAND_FILE is not present. Can not continue..."
fi


#####
## Check if aplicaion WEB_XML present otherwise exit
#####
checkFilePresence $WEBXML_FILE
if [ $IS_FILE_PRESENT -eq 0 ]
then
	error_exit "File $WEBXML_FILE is not present. Can not continue..."
fi

#if [ $IS_STATE_CHANGED -eq 0 ]  
#then
#        stop_webserver
#fi 

######
##Check the arguments
#####
case "$2" in 
enable)
	IS_STATE_CHANGED=0
	http_status_inner
        if [ $IS_HTTPS_ENABLED -eq 1 ]
        then
		IS_STATE_CHANGED=`$EXPR $IS_STATE_CHANGED + 0`
		$ECHO " Security is already enabled. "
	else
		IS_STATE_CHANGED=`$EXPR $IS_STATE_CHANGED + 1`
		stop_webserver
		http_enable
        fi
     	;;
disable)
	IS_STATE_CHANGED=0
	http_status_inner
	if [ $IS_HTTPS_ENABLED -eq 0 ]
	then
		IS_STATE_CHANGED=`$EXPR $IS_STATE_CHANGED + 0`
		$ECHO " Security is already disabled. "
	else
		IS_STATE_CHANGED=`$EXPR $IS_STATE_CHANGED + 1`
		stop_webserver
		http_disable
	fi
     	;;
status) 
      	http_status
     	;;
*) 
	$ECHO " Usage :| change_eniq_security.sh <web_module_name> disable|enable|status "
   	remove_lock_file
   	exit 10
   	;; 
esac

if [ $IS_STATE_CHANGED -eq 1 ]
then
        start_webserver
fi

remove_lock_file
$RM -rf $TEMP_FILE* 2>&1 > /dev/null
$RM -rf $WEBXML_FILE.backup 2>&1 > /dev/null
$RM -rf $INDEX_HTML.backup 2>&1 > /dev/null
$RM -rf $APP_JNLP.backup 2>&1 > /dev/null
$RM -rf $APP_JNLP_TEMPLATE.backup 2>&1 > /dev/null
