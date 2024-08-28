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
# Name    : install_runtime.sh
# Date    : 13/07/2020(dummy date) Last modified 25/04/2023
# Purpose : Ericsson Network IQ Runtime installation script
# Usage   : install_runtime.sh [-v]
# ********************************************************************

# ********************************************************************
#
#   Commands Section
#
# ********************************************************************
AWK=/usr/bin/awk
BASH=/usr/bin/bash
CAT=/usr/bin/cat
CHMOD=/usr/bin/chmod
CHOWN=/usr/bin/chown
CLEAR=/usr/bin/clear
CP=/usr/bin/cp
CUT=/usr/bin/cut
DATE=/usr/bin/date
ECHO=/usr/bin/echo
FIND=/usr/bin/find
GREP=/usr/bin/grep
GUNZIP=/usr/bin/gunzip
LN=/usr/bin/ln
MKDIR=/usr/bin/mkdir
MV=/usr/bin/mv
PWD=/usr/bin/pwd
RM=/usr/bin/rm
RSYNC=/usr/bin/rsync
SED=/usr/bin/sed
TAR=/usr/bin/tar
TEE=/usr/bin/tee
TOUCH=/usr/bin/touch
UNAME=/usr/bin/uname
UNZIP=/usr/bin/unzip

# ********************************************************************
#
#   Configure Section
#
# ********************************************************************

#Force Flag
FORCE=0
#Verbose Flag
VERBOSE=0
#Configured Flag
CONFIGURED=0
#IP Address Variable
IP_ADDRESS=""
#Upgrade Flag
UPGRADE="false"
#Current Working Directory
CURRENT_DIR=`pwd`
#OS Flag
OSTYPE=$($UNAME -s)
#Temporary Directory
TEMP_DIR=/var/tmp
#Backup directory for trust certificates
BACKUP=/var/tmp/truststore/
#Path for trust certificates
TRUSTSTORE=/eniq/sw/runtime/jdk/jre/lib/security/
#Path for webapp Admin UI
ADMINUI_CONF_DIR=/eniq/sw/runtime/tomcat/webapps/adminui/conf
#Rollback node hardening file
TOMCAT_BACKUP_DIR=/eniq/backup/tomcat_back_up
security_rollback_check=${TOMCAT_BACKUP_DIR}/Rollback_Summary

# ********************************************************************
#
#   Function Section
#
# ********************************************************************
# ---------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------
function _echo(){
	$ECHO ${*} | $TEE -a ${LOG_FILE}
}

# ---------------------------------------------------------------------
# Debug log
# ---------------------------------------------------------------------
function _debug(){
	if [ $VERBOSE = 1 ] ; then
		_echo ${*}
	fi
}

# ---------------------------------------------------------------------
# Find .nfs Files
# ---------------------------------------------------------------------
remove_hidden_files() {
	$FIND ${RT_DIR} -type f -name .nfs\* -exec $RM -f {} \;
	$TOUCH /tmp/nfs_list
	$FIND ${RT_DIR} -type f -name .nfs\* >> /tmp/nfs_list

	# Remove all the hidden files from above directories
	while read first_line; do
		if [ -f "$first_line"  ]; then
			remove_file $first_line
		fi
	done < "/tmp/nfs_list"
}

# ---------------------------------------------------------------------
# Remove .nfs Files
# ---------------------------------------------------------------------
remove_file(){
	local _hidden_file_=$1
	lsof | $GREP $_hidden_file_ | $AWK -F" " '{print $2}' | sort | uniq > /tmp/nfs_list_pid
	while read PID 
	do
		kill -9 $PID > /dev/null 2>&1
	done < "/tmp/nfs_list_pid"
	$RM -f $_hidden_file_
}

# ---------------------------------------------------------------------
# JAVA installation
# ---------------------------------------------------------------------
function install_java(){
	_echo "Installing JDK"
	if [ -x /eniq/sw/bin/webserver ] ; then
		/eniq/sw/bin/webserver stop
	fi

	$FIND ${RT_DIR}/ -type f -name .nfs\* -exec $RM -f {} \;
	cd $CURRENT_DIR
	if [[ ${OSTYPE} == CYGWIN* ]] ; then
		PROSTYPE="i386"
	else
		PROSTYPE=`$UNAME -p`
	fi

	if [ -h ${RT_DIR}/jdk ] ; then
		oldversion=$(basename $(ls -l ${RT_DIR}/jdk | $AWK '{print $NF}'))
		_debug "Current JDK Version is $oldversion"
		# Get the new version being installed
		jdk_pkgfile=$(cd jdk/${PROSTYPE}/; ls jdk*)
		newversion=$(basename $jdk_pkgfile .tar.gz)
		_debug "New JDK Version is $newversion"
		if [ $oldversion == $newversion -a $FORCE -eq 0 ] ; then
			_echo "JDK Version ${newversion} already installed."
			_debug "Setting exec permissions to Java."
			$CHMOD 740 ${RT_DIR}/java/bin/*
			if [ ${PROSTYPE} = "i386" ]; then
				$CHMOD 740 ${RT_DIR}/jdk/bin/*
			elif [ ${PROSTYPE} = "x86_64" ]; then
				$CHMOD 740 ${RT_DIR}/jdk/bin/*
			fi
			_debug "Exec permissions to Java set."
			return
		elif [ -h ${RT_DIR}/jdk ] ; then
			_echo "Reinstalling JDK Version $newversion"
		fi
	fi
	
	_echo "Installing Java"
	JAVA_TMP=

	if [ -h ${RT_DIR}/java ] ; then
		_debug "removing old java..."
		$RM -f ${RT_DIR}/java >> ${LOG_FILE} > /dev/null 2>&1
		$RM -f ${RT_DIR}/jdk >> ${LOG_FILE} > /dev/null 2>&1
		$RM -rf ${RT_DIR}/jre* >> ${LOG_FILE} > /dev/null 2>&1
		$RM -rf ${RT_DIR}/jdk* >> ${LOG_FILE} > /dev/null 2>&1
		_debug "old java removed..."
	fi
	
	if [ ${PROSTYPE} = "i386" ]; then
		_echo "Server Type is : ${PROSTYPE}, installing JDK on this."
		cd jdk
		cd i386
		JAVA_TMP=`ls jdk*`
	elif [ ${PROSTYPE} = "x86_64" ]; then 
		_echo "Server Type is : ${PROSTYPE}, installing JDK on this."
		cd jdk
		cd x86_64
		JAVA_TMP=`ls jdk*`
	fi

	$CP ${JAVA_TMP} ${RT_DIR} >> ${LOG_FILE}
	cd ${RT_DIR}
	_debug "Extracting java..."
	$GUNZIP ${JAVA_TMP} >> ${LOG_FILE} 2>&1
	JAVA_TMP=`basename ${JAVA_TMP} .gz`
	_flags="xf"
	if [ $VERBOSE = 1 ] ; then
		_flags="xvf"
	fi

	$TAR ${_flags} ${JAVA_TMP} >> ${LOG_FILE}
	$RM ${JAVA_TMP} >> ${LOG_FILE}
	JAVA_DIR=`basename ${JAVA_TMP} .tar`
	_debug "Linking java..."
	if [ ${PROSTYPE} = "i386" ]; then
		_echo "Server Type is : ${PROSTYPE}, Linking Java..."
		$LN -s ${JAVA_DIR} java >> ${LOG_FILE}
		$LN -s ${JAVA_DIR} jdk >> ${LOG_FILE}
		
	elif [ ${PROSTYPE} = "x86_64" ]; then
		_echo "Server Type is : ${PROSTYPE}, Linking Java..."
		$LN -s ${JAVA_DIR} java >> ${LOG_FILE}
		$LN -s ${JAVA_DIR} jdk >> ${LOG_FILE}
	fi

	_debug "Java is installed."
	_debug "Setting exec permissions to Java."
	$CHMOD 740 ${RT_DIR}/java/bin/*
	if [ ${PROSTYPE} = "i386" ]; then
		$CHMOD 740 ${RT_DIR}/jdk/bin/*
	elif [ ${PROSTYPE} = "x86_64" ]; then
		$CHMOD 740 ${RT_DIR}/jdk/bin/*
	fi

	_debug "Exec permissions to Java set."
	JAVA_HOME=${RT_DIR}/java
	export JAVA_HOME
	cd $CURRENT_DIR
}

# ---------------------------------------------------------------------
# ANT installation
# ---------------------------------------------------------------------
function install_ant(){
	_echo "Installing Ant"
	cd $CURRENT_DIR
	if [ -h ${RT_DIR}/ant ]; then
		oldversion=$(basename $(ls -l ${RT_DIR}/ant | $AWK '{print $NF}'))
		_debug "Current Ant Version is $oldversion"
		# Get the new version being installed
		ant_pkgfile=$(cd ant; ls apache-ant*)
		newversion=$(basename $ant_pkgfile -bin.tar.gz)
		_debug "New Ant Version is $newversion"
		
		# Removing favicon.ico  for EQEV-78128
		if [ -f ${RT_DIR}/ant/manual/favicon.ico ]; then
			$RM -f ${RT_DIR}/ant/manual/favicon.ico
		fi
		if [ -f ${RT_DIR}/ant/manual/favicon.ico ]; then
			_echo "failed to remove favicon.ico file from ant bundle"
		fi
		#end of code of favicon.ico file removal
		
		# Removing ftp.html  for EQEV-100127
		if [ -f ${RT_DIR}/ant/manual/Tasks/ftp.html ]; then
			$RM -f ${RT_DIR}/ant/manual/Tasks/ftp.html
		fi
		if [ -f ${RT_DIR}/ant/manual/Tasks/ftp.html ]; then
			_echo "failed to remove ftp.html file from ant bundle"
		fi
		#end of code of ftp.html file removal

		
		if [ $oldversion == $newversion -a $FORCE -eq 0 ] ; then
			_echo "Ant Version ${newversion} already installed."
			return
		elif [ -h ${RT_DIR}/jdk ] ; then
			_echo "Reinstalling Ant Version $newversion"
		fi
		_debug "removing old ant..."
		$RM -f ${RT_DIR}/ant | $TEE -a ${LOG_FILE}
		$RM -rf ${RT_DIR}/apache-ant* | $TEE -a ${LOG_FILE}
		_debug "old ant removed..."
	fi

	cd ant
	ANT_TMP=`ls apache-ant*`
	$CP ${ANT_TMP} ${RT_DIR} | $TEE -a ${LOG_FILE}
	cd ${RT_DIR}
	_debug "Extracting ant..."
	$GUNZIP ${ANT_TMP} >> ${LOG_FILE} 2>&1
	ANT_TMP=`basename ${ANT_TMP} .gz`
	if [ $VERBOSE = 1 ] ; then
		$TAR xvf ${ANT_TMP} >> ${LOG_FILE} 2>&1
	else
		$TAR xf ${ANT_TMP} >> ${LOG_FILE} 2>&1
	fi
	
	$RM ${ANT_TMP}

	# List ant, remove tar file, replace all spaces with one space and then get the last column i.e. the dir name
	ANT_DIR=`ls -dl apache-ant* | $GREP -v \.tar | tr -s ' ' ' ' | $AWK -F' ' '{print $NF}'`
	if [ -e ant ] ; then
		$RM ant | $TEE -a ${LOG_FILE}
	fi

	_debug "Linking ant..."
	$LN -s ${ANT_DIR} ant | $TEE -a ${LOG_FILE}

	_echo "Ant is successfully installed."
	cd $CURRENT_DIR
}

# ---------------------------------------------------------------------
# Tomcat installation
# ---------------------------------------------------------------------
function install_tomcat(){
	_echo "Installing Tomcat ..."
	cd $CURRENT_DIR	

	# Get the current tomcat version installed
	if [ -h ${RT_DIR}/tomcat ] ; then
		oldversion=$(basename $(ls -l ${RT_DIR}/tomcat | $AWK '{print $NF}'))
	fi

	# Get the new version being installed
	cd tomcat
	tomcat_pkgfile=$(ls apache-tomcat*)
	newversion=$(basename $tomcat_pkgfile .zip)
	
	_echo "Installing version ${newversion}"
	
	#Take webapps and other files backup
	if [ ${UPGRADE} == "true" ] ; then
		if [ ! -d ${RT_DIR}/webapps ]; then 
			$MKDIR -p ${RT_DIR}/webapps
		fi
		
		for webapp in $(ls ${RT_DIR}/tomcat/webapps) ; do
			if [[ ${webapp} != ROOT && ${webapp} != docs && ${webapp} != examples ]] ; then
				_debug "Take backup (${webapp}) to ${RT_DIR}"
				$CP -r ${RT_DIR}/tomcat/webapps/${webapp} ${RT_DIR}/webapps/
			fi
		done
		
		if [ ! -d ${RT_DIR}/tomcat_files ]; then 
			$MKDIR -p ${RT_DIR}/tomcat_files
		fi
		
		if [ -f ${RT_DIR}/tomcat/conf/tomcat-users.xml ] ; then
			_debug "Back up original tomcat-users.xml file"
			$MV ${RT_DIR}/tomcat/conf/tomcat-users.xml ${RT_DIR}/tomcat_files/
		fi
		if [ -f ${RT_DIR}/tomcat/conf/server.xml ] ; then
			_debug "Back up original server.xml file"
			$MV ${RT_DIR}/tomcat/conf/server.xml ${RT_DIR}/tomcat_files/
		fi
		if [ -f ${RT_DIR}/tomcat/conf/Catalina/localhost/adminui.xml ] ; then
			# Copying existing user database conf file, it will get moved to the new install
			_debug "Back up original adminui.xml file"
			$MV ${RT_DIR}/tomcat/conf/Catalina/localhost/adminui.xml ${RT_DIR}/tomcat_files/
		fi			
		if [ -d ${RT_DIR}/tomcat/ssl -a -f ${RT_DIR}/tomcat/ssl/keystore.jks ] ; then
			# Copying existing ssl certificates and private keys
			_debug "Back up ssl directory"				
			$CP -rf ${RT_DIR}/tomcat/ssl ${RT_DIR}/tomcat_files/ssl
		fi
		# This is required for AdminUI Automatic redirect
		if [ -f ${RT_DIR}/tomcat/webapps/ROOT/modified_index.jsp ] ; then
			_debug "Back up original modified_index.jsp file"
			$CP -f ${RT_DIR}/tomcat/webapps/ROOT/modified_index.jsp ${RT_DIR}/tomcat_files/
		fi
		# Backup web.xml file
		if [ -f ${RT_DIR}/tomcat/webapps/adminui/WEB-INF/web.xml ]; then
			_debug "Back up original adminui web.xml file"
			$CP -f ${RT_DIR}/tomcat/webapps/adminui/WEB-INF/web.xml ${RT_DIR}/tomcat_files/adminui_web.xml
		fi
		
		#remove old tomcat
		_echo "Removing the .nfs files under /eniq/sw/runtime/"
		remove_hidden_files

		_echo "Removing older tomcat link."
		$RM -rf ${RT_DIR}/tomcat
		_echo "Removing previously installed Tomcat version."
		$RM -rf ${RT_DIR}/${oldversion}
		
		_echo "Removing the .nfs files [if any] from /eniq/sw/runtime/"
		remove_hidden_files
		
		COUNT=`$FIND ${RT_DIR} -type f -name .nfs\* | wc -l`
		if [ $COUNT -ne 0 ]; then
			_echo ".nfs files are still there. Please follow the WA available in FDD to remove them later."
		fi
		
		if [ -d ${RT_DIR}/${oldversion} ]; then
			sleep 5
			$RM -rf ${RT_DIR}/${oldversion}
			
			if [ -d ${RT_DIR}/${oldversion} ]; then
			_echo "Previous version ${oldversion} was not properly removed. Please follow the WA available in FDD to remove them."
			fi
		fi
	fi

	if [ -d ${RT_DIR}/tomcat -o -h ${RT_DIR}/tomcat ]; then
		_echo "Tomcat directory/link still available. So deleting it again."
		sleep 5
		$RM -rf ${RT_DIR}/tomcat
	fi

	# Copy the zip file to /eniq/sw/runtime
	$CP ${tomcat_pkgfile} ${RT_DIR}/
	_echo "Copied ${tomcat_pkgfile}"
	
	# unzip it
	cd ${RT_DIR}
	_echo "Extracting ${tomcat_pkgfile}"
	$UNZIP -qq ${tomcat_pkgfile} >> ${LOG_FILE} 2>&1
	$CHMOD 755 ${newversion}
	$RM -rf ${RT_DIR}/${tomcat_pkgfile}		

	#Restore webapps and other files.
	if [ -d ${RT_DIR}/webapps ] ; then
		for webapp in $(ls ${RT_DIR}/webapps) ; do
			if [[ ${webapp} != ROOT && ${webapp} != docs && ${webapp} != examples ]] ; then
				_debug "Copying old webapps (${webapp}) to tomcat ${newversion}"
				$CP -r ${RT_DIR}/webapps/${webapp} ${RT_DIR}/${newversion}/webapps/
			fi
		done
	fi
	
	if [ -d ${RT_DIR}/tomcat_files ] ; then
		if [ -f ${RT_DIR}/tomcat_files/tomcat-users.xml ] ; then
			_debug "Moving up original users file"
			$MV ${RT_DIR}/tomcat_files/tomcat-users.xml ${RT_DIR}/${newversion}/conf/
		fi
		if [ -f ${RT_DIR}/tomcat_files/server.xml ] ; then
			_debug "Moving up original server.xml file"
			# $MV ${RT_DIR}/tomcat_files/server.xml ${RT_DIR}/${newversion}/conf/server_orig.xml
			$MV ${RT_DIR}/tomcat_files/server.xml ${RT_DIR}/${newversion}/conf/server.xml
		fi
		if [ -f ${RT_DIR}/tomcat_files/adminui.xml ] ; then
			# Copying existing user database conf file, it will get moved to the new install
			_debug "Copying original adminui.xml file"
			$MKDIR -p ${RT_DIR}/${newversion}/conf/Catalina/localhost/
			$MV ${RT_DIR}/tomcat_files/adminui.xml ${RT_DIR}/${newversion}/conf/Catalina/localhost/
		fi
		if [ -d ${RT_DIR}/tomcat_files/ssl -a -f ${RT_DIR}/tomcat_files/ssl/keystore.jks ] ; then
			# Copying existing ssl certificates and private keys
			_debug "Copying up ssl directory"				
			$CP -rf ${RT_DIR}/tomcat_files/ssl ${RT_DIR}/${newversion}/ssl 
			CONFIGURED=1 
		fi
		# This is required for AdminUI Automatic redirect
		if [ -f ${RT_DIR}/tomcat_files/modified_index.jsp ] ; then
			_debug "Copying original modified_index.jsp file"
			$CP -f ${RT_DIR}/tomcat_files/modified_index.jsp ${RT_DIR}/${newversion}/webapps/ROOT/
		fi
		
		# This is required to remove External URLs
		declare -a arr=("https:\/\/github.com\/apache\/tomcat\/tree\/8.5.x" "https:\/\/tomcat.apache.org\/bugreport.html" "https:\/\/tomcat.apache.org\/" "https:\/\/wiki.apache.org\/tomcat\/FrontPage" "https:\/\/wiki.apache.org\/tomcat\/Specifications" "https:\/\/wiki.apache.org\/tomcat\/TomcatVersions" "https:\/\/www.apache.org\/foundation\/sponsorship.html" "https:\/\/www.apache.org\/foundation\/thanks.html" "https:\/\/www.apache.org")

		for url in "${arr[@]}"
		do
			$GREP $url ${RT_DIR}/${newversion}/webapps/ROOT/modified_index.jsp > /dev/null
			if [ $? -eq 0 ]; then
				sed -i "s/$url//g" ${RT_DIR}/${newversion}/webapps/ROOT/modified_index.jsp
			fi
			
			$GREP $url ${RT_DIR}/${newversion}/webapps/ROOT/modified_index.jsp > /dev/null
			if [ $? -eq 0 ]; then
				_echo "Failed to remove External URL $url"
			fi
			
		done
		
		# Code to replace favicon.ico with eric.ico
        $GREP "favicon.ico" ${RT_DIR}/${newversion}/webapps/ROOT/modified_index.jsp > /dev/null
        if [ $? -eq 0 ]; then
            sed -i 's/favicon.ico/eric.ico/g' ${RT_DIR}/${newversion}/webapps/ROOT/modified_index.jsp
        fi
		$GREP "favicon.ico" ${RT_DIR}/${newversion}/webapps/ROOT/modified_index.jsp > /dev/null
		if [ $? -eq 0 ]; then
			_echo "Failed to replace Favicon.ico reference"
		fi
		
		# Backup web.xml file
		if [ -f ${RT_DIR}/tomcat_files/adminui_web.xml ]; then
			_debug "Copying original adminui web.xml file"
			$CP -f ${RT_DIR}/tomcat_files/adminui_web.xml ${RT_DIR}/${newversion}/webapps/adminui/WEB-INF/web.xml
		fi
		
		_debug "Restore successfully done. Remove ${RT_DIR}/webapps directory"
		$RM -rf ${RT_DIR}/webapps
		$RM -rf ${RT_DIR}/tomcat_files
	fi
	
	_echo "Linking to new version ${newversion}"
	$LN -s ${RT_DIR}/${newversion} ${RT_DIR}/tomcat
	if [ ! -h ${RT_DIR}/tomcat ]; then
		_echo "New version Tomcat link is not available. Retrying..."
		$RM -rf ${RT_DIR}/tomcat
		$LN -s ${RT_DIR}/${newversion} ${RT_DIR}/tomcat
	fi
	
	######## Tomcat package extracted, links are created and user customizable files are retained ########

	cd $CURRENT_DIR
	_debug "Copying user database ..."
	cd adminui_userdb
	$CP user-database.jar ${RT_DIR}/tomcat/lib/
	cd ..
	configure_ssl
	
	_debug "Copying Scripts ..."
	# Copy https_security script
	$CP bin/change_eniq_security.sh ${BIN_DIR}/
	$CHMOD 740 ${BIN_DIR}/change_eniq_security.sh
	
	# Copy renegotiation switch script
	$CP bin/tls_switch.bsh ${RT_DIR}/tomcat/bin
	$CHMOD 740 ${RT_DIR}/tomcat/bin/tls_switch.bsh
	
	# Copy start/stop scripts
	$CP bin/webserver ${BIN_DIR}/
	$CHMOD 740 ${BIN_DIR}/webserver
	$CP bin/before_webserver_start.xml ${BIN_DIR}/ 
	$CP smf/webserver ${ADMIN_BIN}/
	$CHMOD 740 ${ADMIN_BIN}/webserver
	# $CP ${RT_DIR}/tomcat/conf/server.xml ${RT_DIR}/tomcat/conf/server_orig.xml 2>&1 | $TEE -a  ${getLogFileName}
	$CP ${RT_DIR}/tomcat/conf/web.xml ${RT_DIR}/tomcat/conf/web_orig.xml  2>&1 | $TEE -a  ${getLogFileName}

	if [ "$UPGRADE" == "false" ]; then
		$CP conf/* ${RT_DIR}/tomcat/conf/ 2>&1 | $TEE -a  ${getLogFileName}
	else
		$CP conf/enable_server.xml ${RT_DIR}/tomcat/conf/ 2>&1 | $TEE -a  ${getLogFileName}
		$CP conf/disable_server.xml ${RT_DIR}/tomcat/conf/ 2>&1 | $TEE -a  ${getLogFileName}
		$CP conf/password.txt ${RT_DIR}/tomcat/conf/ 2>&1 | $TEE -a  ${getLogFileName}
		$CP conf/web.xml ${RT_DIR}/tomcat/conf/ 2>&1 | $TEE -a  ${getLogFileName}
		
		ORIG_SERVER_XML=${RT_DIR}/tomcat/conf/server.xml
		NEW_SERVER_XML=conf/server.xml
		# Retaining the latest SSLProtocol version in server.xml
		ORIG_SSLPROTOCOL=`$CAT $ORIG_SERVER_XML |  $GREP -o "sslProtocol=\".*\"" | $CUT -d= -f2 | $SED -e 's/^"//' -e 's/"$//'`
		NEW_SSLPROTOCOL=`$CAT $NEW_SERVER_XML |  $GREP -o "sslProtocol=\".*\"" | $CUT -d= -f2 | $SED -e 's/^"//' -e 's/"$//'`
		if [[ "$ORIG_SSLPROTOCOL" != "$NEW_SSLPROTOCOL" ]]; then 
			if [[ $ORIG_SSLPROTOCOL == *"v"* ]]; then
				ORIG_SSLPROTOCOL_VERSION=`$ECHO "$ORIG_SSLPROTOCOL" | $CUT -dv -f2`
			else 
				ORIG_SSLPROTOCOL_VERSION="1"
			fi
			NEW_SSLPROTOCOL_VERSION=`$ECHO "$NEW_SSLPROTOCOL" | $CUT -dv -f2`
			if [[ $($ECHO "$NEW_SSLPROTOCOL_VERSION > $ORIG_SSLPROTOCOL_VERSION" | bc -l) ]]; then
				_echo "Enforcing the latest SSLProtocol version in server.xml"
				if [[ -z "$($GREP -o 'sslEnabledProtocols=\".*\"' $ORIG_SERVER_XML)" ]]; then
					$SED -i "s/sslProtocol=\".*\"/sslEnabledProtocols=\"${NEW_SSLPROTOCOL}\" sslProtocol=\"${NEW_SSLPROTOCOL}\"/" $ORIG_SERVER_XML
				else
					$SED -i "s/sslEnabledProtocols=\".*\"/sslEnabledProtocols=\"${NEW_SSLPROTOCOL}\"/" $ORIG_SERVER_XML
					$SED -i "s/sslProtocol=\".*\"/sslProtocol=\"${NEW_SSLPROTOCOL}\"/" $ORIG_SERVER_XML
				fi
			fi
		fi

		#If the security features are enabled on the system then
		if [ -d ${TOMCAT_BACKUP_DIR} ]; then
			$LS ${TOMCAT_BACKUP_DIR} | $GREP Rollback_Summary_ > /dev/null
			if [ $? -eq 0 ];then
				for file in `$LS ${TOMCAT_BACKUP_DIR}/Rollback_Summary_*`; do 
					$MV $file ${TOMCAT_BACKUP_DIR}/Rollback_Summary
				done
			fi
		fi
		#VALUE=`$CAT $security_rollback_check |$GREP LOCKOUT |$AWK -F ":" '{print $2}'`
		if [ -f $security_rollback_check ] && [ "`$CAT $security_rollback_check |$GREP LOCKOUT |$AWK -F ":" '{print $2}'`" == "FALSE" ]; then
			_echo "Found security features has been disabled manually on the system. Skipping the lockout security patches."
		else
			# Retaining Server.xml changes for lockout realm
			line=`$CAT $ORIG_SERVER_XML | $GREP "org.apache.catalina.realm.LockOutRealm"`
			count=`$CAT $ORIG_SERVER_XML | $GREP -P -o -e '(?<=failureCount=").*?(?=")'`
			time=`$CAT $ORIG_SERVER_XML | $GREP -P -o -e '(?<=lockOutTime=").*?(?=")'`
			FailureCount=""
			LockOutTime=""
			if [[ -z $count ]]; then
				FailureCount="failureCount=\"3\""
			else			
				FailureCount="failureCount=\"$count\""
			fi
			if [[ -z $time ]]; then
				LockOutTime="lockOutTime=\"3600\""		
			else
				LockOutTime="lockOutTime=\"$time\""
			fi
			replaceString="<Realm className=\"org.apache.catalina.realm.LockOutRealm\" $FailureCount $LockOutTime>"
			$SED -i "s/$line/$replaceString/" $ORIG_SERVER_XML
		fi
		
			# Enforcing SSLHonorCipherOrder for cipher suite priority
		#VALUE=`$CAT $security_rollback_check |$GREP CIPHER_PROP |$AWK -F ":" '{print $2}'`
		if [ -f $security_rollback_check ] && [ "`$CAT $security_rollback_check |$GREP CIPHER_PROP |$AWK -F ":" '{print $2}'`" == "FALSE" ]; then
			_echo "Found security features has been disabled manually on the system. Skipping the Cipher security patches."
		else
			SSLCipherSuite_org=`$CAT $ORIG_SERVER_XML | $GREP -Poe '(?>SSLCipherSuite=").*?(?=")"'`
			SSLCipherSuite_new=`$CAT $NEW_SERVER_XML| $GREP "SSLCipherSuite" | $TR -d " "`
			SSLHonorCipherOrder_old=`$CAT $ORIG_SERVER_XML | $GREP -Poe '(?>SSLHonorCipherOrder=").*?(?=")"'`
			SSLHonorCipherOrder_new=`$CAT $NEW_SERVER_XML| $GREP "SSLHonorCipherOrder"`
			ORIG_CIPHERS=`$CAT $ORIG_SERVER_XML | $GREP -Poe '(?>ciphers=").*?(?=")"'`
			
			if [[ ! -z $ORIG_CIPHERS ]]; then
			$SED -i "s/ciphers=\"[^\"]*\"//" $ORIG_SERVER_XML
			fi
			
			if [[ ! -z $SSLCipherSuite_org ]]; then
				 $SED -i "s/${SSLCipherSuite_org}/${SSLCipherSuite_new}/g" $ORIG_SERVER_XML
			else
				 $SED -i "/sslProtocol=/ s/^\(.*\)\(\/>\|$\)/\1 \n${SSLCipherSuite_new}\2/" $ORIG_SERVER_XML
			fi
			
			if [[ ! -z $SSLHonorCipherOrder_old ]]; then
				 $SED -i "s/${SSLHonorCipherOrder_old}/${SSLHonorCipherOrder_new}/g" $ORIG_SERVER_XML
			else
				 $SED -i "/SSLCipherSuite=/ s/^\(.*\)\(\/>\|$\)/\1 \n${SSLHonorCipherOrder_new}\2/" $ORIG_SERVER_XML
			fi
					
		fi
		
        #AJP connector disabling...	
		
		Ajp_line=`$CAT $ORIG_SERVER_XML | $GREP 'Connector port="8009" protocol="AJP\/1.3" redirectPort="8443"'`
		SERVER_TEMP_XML=${RT_DIR}/SERVER_TEMP.xml
		if [[ ! -z $Ajp_line ]]; then
		    $SED 's/<Connector port="8009" protocol="AJP\/1.3" redirectPort="8443" \/>/<!-- <Connector protocol="AJP\/1.3" address="::1" port="8009" redirectPort="8443" \/>-->/g' $ORIG_SERVER_XML > $SERVER_TEMP_XML
			result=$?
			if [ $result -eq 0 ]; then 
			   $MV $SERVER_TEMP_XML $ORIG_SERVER_XML
			   $RM -f $SERVER_TEMP_XML
			fi
		fi
		
		# Disabling connection to 8080 port
		port_8080_line=`$GREP 'Connector port="8080" protocol="HTTP\/1.1"' $ORIG_SERVER_XML`		
		SERVER_TEMP1_XML=${RT_DIR}/SERVER_TEMP1.xml
		SERVER_TEMP2_XML=${RT_DIR}/SERVER_TEMP2.xml		
		if [[ ! -z $port_8080_line ]]; then
		   port_8080_lineNumber=`$GREP -n 'Connector port="8080" protocol="HTTP\/1.1"' $ORIG_SERVER_XML| cut -f1 -d:`		   
		   if [[ ! -z $port_8080_lineNumber ]]; then
		      check_redirectport_variable=`awk 'c&&!--c;/Connector port="8080"/{c=2}' $ORIG_SERVER_XML`			  
			  if [[ $check_redirectport_variable == *'redirectPort="8443"'* ]]; then
			     $SED 's/<Connector port="8080" protocol="HTTP\/1.1"/<!-- <Connector protocol="HTTP\/1.1" port="8080"/g' $ORIG_SERVER_XML > $SERVER_TEMP1_XML
			     if [ $? -eq 0 ]; then
				    redirectPort_lineNumber=$(($port_8080_lineNumber + 2))					
				    $SED  "${redirectPort_lineNumber}"'s/redirectPort="8443" \/>/redirectPort="8443" \/>-->/g' $SERVER_TEMP1_XML > $SERVER_TEMP2_XML					
				    if [ $? -eq 0 ]; then
					$MV $SERVER_TEMP2_XML $ORIG_SERVER_XML					
					$RM -f $SERVER_TEMP1_XML
					$RM -f $SERVER_TEMP2_XML
					
					fi				
				 fi
				else 
                    _echo "Cannot disable the 8080 port as manual change has been performed on the server.xml script" 				
			  fi			 
		   fi          		
	    fi   
				
	    LocalHost_Access_Log=`cat /eniq/sw/runtime/tomcat/conf/server.xml | grep "%a \+%u \+%{yyyy-MM-dd hh:mm:ss aa}t \+&quot;%r&quot; \+%s \+%D"`
		if [[ ! -z $LocalHost_Access_Log ]]; then
			OldLocalHost_Access_Log="\%r\&quot\; \%s \%D"
			NewLocalHost_Access_Log="\%\{maskedPath\}r\&quot\; \%m \%U \%H \%s \%D"
			$SED -i "s|${OldLocalHost_Access_Log}|${NewLocalHost_Access_Log}|g" $ORIG_SERVER_XML
		fi
		    Old_Date_LocalHost_Access_Log="\%{yyyy-MM-dd hh:mm:ss}t"
	        New_Date_LocalHost_Access_Log="\%{yyyy-MM-dd hh:mm:ss aa }t"
	        $SED -i "s|${Old_Date_LocalHost_Access_Log}|${New_Date_LocalHost_Access_Log}|g" $ORIG_SERVER_XML
		
		
		# if [ -f ${RT_DIR}/${newversion}/conf/server_orig.xml ]; then
			# ORIG_SERVER_XML=${RT_DIR}/${newversion}/conf/server_orig.xml
			# ORIG_SSLPROTOCOL=`cat $ORIG_SERVER_XML |  grep -o "sslProtocol=.*" | cut -d= -f2 | sed -e 's/^"//' -e 's/"$//'`
			# ORIG_KEYSTORE_PASS=`cat $ORIG_SERVER_XML |  grep -o "keystorePass=.*" | cut -d= -f2 | sed -e 's/^"//' -e 's/"$//'`
			# SERVER_XML=${RT_DIR}/${newversion}/conf/server.xml
			# SSLPROTOCOL=`cat $SERVER_XML |  grep -o "sslProtocol=.*" | cut -d= -f2 | sed -e 's/^"//' -e 's/"$//'`
			# KEYSTORE_PASS=`cat $SERVER_XML |  grep -o "keystorePass=.*" | cut -d= -f2 | sed -e 's/^"//' -e 's/"$//'`
			# if [ $ORIG_SSLPROTOCOL =~ ^TLS.*$ && $SSLPROTOCOL =~ ^TLS.*$ ]; then
				# if [ $(expr ${ORIG_SSLPROTOCOL} \<= ${SSLPROTOCOL}) -eq 1 ]; then 
					# keep new server.xml file
					# restore keystore password
					# sed -i "s/${ORIG_KEYSTORE_PASS}/${KEYSTORE_PASS}/g" $SERVER_XML
					# restore original ciphers
					# ORIG_CIPHERS=`cat $ORIG_SERVER_XML |  grep -o "ciphers=.*" | cut -d= -f2`
					
				# else
					# keep original sevrer.xml file
					# remove new server.xml
					# rm $SERVER_XML
					# mv $ORIG_SERVER_XML $SERVER_XML
				# fi
			# elif [ $SSLPROTOCOL =~ ^TLS.*$ ];then 
				# keep new server.xml file
				# restore keystore password
				# sed -i "s/${ORIG_KEYSTORE_PASS}/${KEYSTORE_PASS}/g" $SERVER_XML
			# else
				# retain original server.xml file
				# rm $SERVER_XML
				# mv $ORIG_SERVER_XML $SERVER_XML
			# fi
		# fi
	fi
	_echo "Copying common_variables.lib to ${BIN_DIR}"
	$CP conf/common_variables.lib ${BIN_DIR}/
	if [ $? -ne 0 ]; then 
		_echo "common_variables.lib failed to copy to ${BIN_DIR}"
	else
		_echo "common_variables.lib copied to ${BIN_DIR}"
	fi
	$CHMOD 644 ${BIN_DIR}/common_variables.lib
	$CHMOD 644 ${RT_DIR}/tomcat/conf/server.xml
	$CHMOD 644 ${RT_DIR}/tomcat/conf/enable_server.xml
	$CHMOD 644 ${RT_DIR}/tomcat/conf/disable_server.xml
	if [ -f ${RT_DIR}/tomcat/conf/server.xml -a -f ${RT_DIR}/tomcat/conf/web.xml ] ; then
		_debug "Server and web files copied"
	else
		_echo "Server and web files not found. Exiting."
		exit 100
	fi

	webserver status > /dev/null 2>&1
	if [ $? -eq 1 ] ; then
		_echo "Starting Tomcat ..."
		result=$(webserver start)
	else
		_echo "Restarting Tomcat ..."
		result=$(webserver restart)
	fi

	webserver status > /dev/null 2>&1
	if [ $? -ne 0 ] ; then
		_echo "Tomcat failed to start:"
		_echo "Reason : ${result}"
		exit 101
	else
		cd $CURRENT_DIR
		_echo "Tomcat is successfully installed."
	fi
	# Removing tomcat-users.xml for EQEV-47386
	if [ -f ${ADMINUI_CONF_DIR}/tomcat-users.xml ]; then
		$RM -rf ${ADMINUI_CONF_DIR}/tomcat-users.xml
	fi
}

# ---------------------------------------------------------------------
# Read IP Address
# ---------------------------------------------------------------------
function ip_address(){
	SERVICE_NAME=/eniq/sw/conf/service_names
	HOST_FILE=/etc/hosts
	if [ -f $SERVICE_NAME ]; then
		_echo "Reading IP from serivce_name file"
		IP_ADDRESS=`cat /eniq/sw/conf/service_names | $GREP webserver | $AWK -F"::" '{print $1}'`
		_echo "$IP_ADDRESS"
	else
		_echo "Reading IP from Hosts file"
		IP_ADDRESS=`cat /etc/hosts | $GREP webserver | $AWK -F" " '{print $1}'`
		_echo "$IP_ADDRESS"
	fi
}

# ---------------------------------------------------------------------
# Configure Tomcat for SSL
# ---------------------------------------------------------------------
function configure_ssl(){
	_echo "Configuring Tomcat for SSL ..."	
	if [ ! -d ${RT_DIR}/tomcat/ssl ]; then
		$MKDIR ${RT_DIR}/tomcat/ssl
	fi
	if [ ! -d ${RT_DIR}/tomcat/ssl/private ]; then
		$MKDIR -p ${RT_DIR}/tomcat/ssl/private
	fi
	$CHMOD og-rwx ${RT_DIR}/tomcat/ssl/private
	ENIQ_INI="niq.ini"
	ENIQ_BASE_DIR="/eniq"
	ENIQ_CONF_DIR="/eniq/sw/conf"
	COMMON_FUNCTIONS=${ENIQ_BASE_DIR}/installation/core_install/lib/common_functions.lib
	if [ -f ${COMMON_FUNCTIONS} ] ; then
		. ${COMMON_FUNCTIONS}
	else
		_echo "Cant not find file ${COMMON_FUNCTIONS}"
		exit 53
	fi
	KEYSTOREPASSWORD=`inigetpassword KEYSTOREPASS -f ${ENIQ_CONF_DIR}/${ENIQ_INI} -v keyStorePassValue`
	
	#OpenSSL Warning supress
	#For Linux Porting code commented 
	#export OPENSSL_CONF=/etc/openssl/openssl.cnf		 
	export OPENSSL_CONF=/etc/pki/tls/openssl.cnf
	
	HOST=/usr/bin/host 	
	HOSTNAME=`/usr/bin/hostname`
	FULLNAME=`$ECHO \`$HOST $HOSTNAME\` | $AWK '{print $1;}'`
	PRIVATEKEY=${RT_DIR}/tomcat/ssl/private/$HOSTNAME-private.pem
	PUBLICKEY=${RT_DIR}/tomcat/ssl/${HOSTNAME}_public.key
	CERTFILE=${RT_DIR}/tomcat/ssl/$HOSTNAME.cer
	CSRFILE=${RT_DIR}/tomcat/ssl/$HOSTNAME.csr
	P12KEYSTORE=${RT_DIR}/tomcat/ssl/keystore.pkcs12
	JKEYSTORE=${RT_DIR}/tomcat/ssl/keystore.jks
	#For Linux Porting code commented 
	#OPENSSL=/usr/sfw/bin/openssl
	OPENSSL=/usr/bin/openssl
	KEYTOOL=${RT_DIR}/java/bin/keytool
	HOSTOUTPUT=`$ECHO \`$HOST $HOSTNAME\` | $GREP "has address"`
	
	if [ $CONFIGURED = 0 ] ; then
		if [ ! "${HOSTOUTPUT}" ]; then
			_echo "FULL name was not found in DNS lookup,using IP address "
			ip_address
			FULLNAME=$IP_ADDRESS
		fi

		_echo "Generating JKS Keystore"	
		$KEYTOOL -genkeypair -keystore $JKEYSTORE -storepass ${KEYSTOREPASSWORD} -alias eniq -keypass ${KEYSTOREPASSWORD} -keysize 2048 -keyalg RSA -sigalg SHA256withRSA -dname "CN=$FULLNAME" -validity 825
		if [ $? -ne 0 ] ; then
			_echo "Failed to generate JKS Keystore. Exiting...."
			exit 0
		else
			_echo "Converting the existing JKS keystore to PKCS12 Keystore"
			$KEYTOOL -importkeystore -srckeystore $JKEYSTORE -destkeystore $P12KEYSTORE -srcstoretype JKS -deststoretype PKCS12 -srcstorepass ${KEYSTOREPASSWORD} -deststorepass ${KEYSTOREPASSWORD} -srcalias eniq -destalias eniq -srckeypass ${KEYSTOREPASSWORD} -destkeypass ${KEYSTOREPASSWORD}
			_echo "Exporting Self_signed Certificate"
			$KEYTOOL -exportcert -keystore $JKEYSTORE -storepass ${KEYSTOREPASSWORD} -alias eniq -keypass ${KEYSTOREPASSWORD} -file $CERTFILE
			$CHMOD 0400 $CERTFILE
			_echo "Generating Certificate Signing Request"
			$KEYTOOL -certreq -keystore $JKEYSTORE -storepass ${KEYSTOREPASSWORD} -alias eniq -keypass ${KEYSTOREPASSWORD} -file $CSRFILE
			_echo "Generating Private key"
			$OPENSSL pkcs12 -in $P12KEYSTORE -out $PRIVATEKEY -passin pass:${KEYSTOREPASSWORD} -passout pass:${KEYSTOREPASSWORD}
			$CHMOD 0400 $PRIVATEKEY
		fi		
		_echo "Tomcat is configured for SSL."		
	else
		_echo "Tomcat is already configured for SSL"
	fi	
	
}

# ---------------------------------------------------------------------
# Check Tomcat for SSL Configuration
# ---------------------------------------------------------------------
function is_ssl_configured(){
	ssl_dir=${RT_DIR}/tomcat/ssl
	if [ -d ${RT_DIR}/tomcat/ssl -a -f ${RT_DIR}/tomcat/ssl/keystore.jks ] ; then	
		return 0
	else
		return 1
	fi
}

# ---------------------------------------------------------------------
# Return the Version
# ---------------------------------------------------------------------
function get_version_tag(){
	version_properties=${1}
	if [ ! -f ${version_properties} ] ; then
		_echo "File ${version_properties} not found"
		return 4
	fi
	version=$($GREP module.version ${version_properties} | cut -d= -f2)
	build=$($GREP module.build ${version_properties} | cut -d= -f2)
	$ECHO "${version}b${build}"
	return 0
}

getChar() {
    expr match "$1" "\([^[:digit:]]*\)"
}

getCharRemainder() {
    expr match "$1" "[^[:digit:]]*\(.*\)"
}

getNum() {
    expr match "$1" "\([[:digit:]]*\)"
}

getNumRemainder() {
    expr match "$1" "[[:digit:]]*\(.*\)"
}

# return 0 for equal
# return 1 for oldRState > newRState
# return 2 for oldRState < newRState
rStateCompare() {
    local oldRState="$1"
	local newRState="$2"
    local oldRStateNum="", newRStateNum="", oldRStateChar="", newRStateChar=""
    while true; do
        oldRStateChar=`getChar "${oldRState}"`
        newRStateChar=`getChar "${newRState}"`
        oldRState=`getCharRemainder "${oldRState}"`
        newRState=`getCharRemainder "${newRState}"`

        if [[ $oldRStateChar == *"_"* ]] && [[ ! $newRStateChar == *"_"* ]]; then
		    return 1
		elif [[ ! $oldRStateChar == *"_"* ]] && [[  $newRStateChar == *"_"* ]]; then
            return 2
        elif [ "${oldRStateChar}" \> "${newRStateChar}" ]; then
            return 1
        elif [ "${oldRStateChar}" \< "${newRStateChar}" ]; then
            return 2
        fi

        oldRStateNum=`getNum "${oldRState}"`
        newRStateNum=`getNum "${newRState}"`
        oldRState=`getNumRemainder "${oldRState}"`
        newRState=`getNumRemainder "${newRState}"`

        if [ -z "${oldRStateNum}" -a -z "${newRStateNum}" ]; then
            return 0
        elif [ -z "${oldRStateNum}" -a -n "${newRStateNum}" ]; then
            return 2
        elif [ -n "${oldRStateNum}" -a -z "${newRStateNum}" ]; then
            return 1
        fi

        if [ "${oldRStateNum}" -gt "${newRStateNum}" ]; then
            return 1
        elif [ "${oldRStateNum}" -lt "${newRStateNum}" ]; then
            return 2
        fi
    done
}

# ---------------------------------------------------------------------
# Check is Runtime Install
# ---------------------------------------------------------------------
function is_installed(){
	newVersion=${1}
	if [ -f ${INSTALLER_DIR}/versiondb.properties ] ; then
		oldVersion=$($GREP module.runtime= ${INSTALLER_DIR}/versiondb.properties | $CUT -d= -f2)
		if [ -z "${oldVersion}" ] ; then
			# _echo "Not able to fetch old R-State. oldRState : ${oldVersion}"
			_echo "Installation started..."
			return 1
		else 
			_echo "Starting version check..."
			rStateCompare ${newVersion} ${oldVersion}
			returnState=$?
			if [ ${returnState} == 0 ] ; then
				# _echo "Same version is already installed. Skipped ${module_name} installation."
				return 0
			elif [ ${returnState} == 1 ] ; then
				_echo "Lower version ${oldVersion} found. Installing new version ${newVersion}"
				return 1
			elif [ ${returnState} == 2 ]; then
				# _echo "Already higher version ${oldVersion} is installed. Skipped ${module_name} installation."
				return 0
			fi
		fi
		# $GREP "module.runtime=${version}" ${INSTALLER_DIR}/versiondb.properties > /dev/null
		# return $?
	else
		return 2
	fi
}

# ---------------------------------------------------------------------
# Update or create versiondb.properties
# ---------------------------------------------------------------------
function update_versiondb(){
	_debug "Updating version database..."
	VTAG="module.runtime="$(get_version_tag install/version.properties)

	if [ ! -f ${INSTALLER_DIR}/versiondb.properties ] ; then
		$ECHO "${VTAG}" > ${INSTALLER_DIR}/versiondb.properties
		$CHMOD 640 ${INSTALLER_DIR}/versiondb.properties
	else

	OLD=$($GREP module.runtime ${INSTALLER_DIR}/versiondb.properties)

	if [ -z "${OLD}" ] ; then
		$ECHO "${VTAG}" >> ${INSTALLER_DIR}/versiondb.properties
	else
		$CP ${INSTALLER_DIR}/versiondb.properties ${INSTALLER_DIR}/versiondb.properties.tmp
		$SED -e "/${OLD}/s//${VTAG}/g" ${INSTALLER_DIR}/versiondb.properties.tmp > ${INSTALLER_DIR}/versiondb.properties
		$RM ${INSTALLER_DIR}/versiondb.properties.tmp
	fi
fi
}

# ---------------------------------------------------------------------
# Pre java install
# ---------------------------------------------------------------------
function pre_javainstall(){
	if [ -f ${TRUSTSTORE}/truststore.ts ] ; then
		_echo "Taking backup of truststore.ts file before java upgrade..."
		if [ ! -d ${BACKUP} ] ; then
			$MKDIR ${BACKUP}
			$CHOWN dcuser:dc5000 ${BACKUP}
			$CHMOD 755 ${BACKUP}
		fi

		$CP ${TRUSTSTORE}/truststore.ts ${BACKUP}
		if [ $? == 0 ] ; then
			_echo "truststore.ts file is successfully copied in the path ${BACKUP}"
		else
			_echo "truststore.ts file is not copied in the path ${BACKUP}"
		fi
		
		if [ -f ${BACKUP}/truststore.ts ] ; then
			$CHOWN dcuser:dc5000 ${BACKUP}/truststore.ts
			$CHMOD 744 ${BACKUP}/truststore.ts
		fi
	fi
}

# ---------------------------------------------------------------------
# Post java install
# ---------------------------------------------------------------------
function post_javainstall(){
	if [ -f ${BACKUP}/truststore.ts ] ; then
		_echo "Restoring of truststore.ts file after java upgrade..."
		$CP ${BACKUP}/truststore.ts ${TRUSTSTORE}
		if [ $? == 0 ] ; then
			_echo "truststore.ts file successfully restored in the path ${TRUSTSTORE}"
			$RM -rf ${BACKUP}
			if [ $? == 0 ] ; then
				_echo "${BACKUP} is successfully deleted as part of cleanup"
			else
				_echo "${BACKUP} is not deleted as part of cleanup"
			fi
		else
			_echo "truststore.ts file is not restored in the path ${TRUSTSTORE}"
		fi
		
		if [ -f ${TRUSTSTORE}/truststore.ts ] ; then
			$CHOWN dcuser:dc5000 ${TRUSTSTORE}/truststore.ts
			$CHMOD 744 ${TRUSTSTORE}/truststore.ts
		fi
	fi
}

# ---------------------------------------------------------------------
# Sets tls renegotiation limit appropriately
# ---------------------------------------------------------------------
function set_tls_renegotiation(){
	_echo "Disabling the TLS/SSL renegotiation"
	$BASH ${RT_DIR}/tomcat/bin/tls_switch.bsh disable
	if [ $? -ne 0 ] ; then
		_echo "Failed to disable TLS/SSL renegotiation."
	fi
}

# ********************************************************************
#
#   Main Script
#
# ********************************************************************
while getopts  "vfl:" flag ; do
	case $flag in
	v)
		VERBOSE=1
		;;
	f)
		FORCE=1
		;;
	l)  getLogFileName="$OPTARG"
		;;
	esac
done

if [ -z "${CONF_DIR}" ] ; then
  $ECHO "ERROR: CONF_DIR is not set"
  exit 1
fi

if [ ! -r "${CONF_DIR}/niq.rc" ] ; then
  $ECHO "ERROR: Source file is not readable at ${CONF_DIR}/niq.rc"
  exit 2
fi

. ${CONF_DIR}/niq.rc

if [ ! -d "${LOG_DIR}/platform_installer" ] ; then
	$MKDIR ${LOG_DIR}/platform_installer
fi

TIMESTAMP=`$DATE +%d.%m.%y_%H:%M:%S`
LOG_FILE=${LOG_DIR}/platform_installer/runtime_${TIMESTAMP}.log

#Check for Upgrade or initial install
# if [ -f ${RT_DIR}/tomcat/conf/enable_server.xml ] ; then
	# UPGRADE="true"
	# FORCE=1
# fi
if [ -z "$(ls -A /eniq/sw/runtime)" ]; then
   # echo "Empty"
   # II_FLAG="true"
   UPGRADE="false"
else
   # echo "Not Empty"
   # II_FLAG="false"
   UPGRADE="true"
fi

new_version=$(get_version_tag install/version.properties)
if [ $? -ne 0 ] ; then
	$ECHO ${ci}
	exit ${ok}
fi

_debug "Checking ${new_version}"
is_installed ${new_version}
is_installed_check=$?

if [ ${FORCE} -eq 0 ]; then
	if [ ${is_installed_check} -eq 0 ] ; then 
		_echo "Runtime version ${new_version} or higher already installed."
		is_ssl_configured
		if [ $? -ne 0 ] ; then	
			configure_ssl
			# $CP ${RT_DIR}/tomcat/conf/server.xml ${RT_DIR}/tomcat/conf/server_orig.xml
			$CP conf/enable_server.xml ${RT_DIR}/tomcat/conf/
			$CP conf/disable_server.xml ${RT_DIR}/tomcat/conf/
			$CP conf/password.txt ${RT_DIR}/tomcat/conf/
			_echo "Copying common_variables.lib to ${BIN_DIR}"
			$CP conf/common_variables.lib ${BIN_DIR}/
			if [ $? -ne 0 ]; then 
				_echo "common_variables.lib failed to copy to ${BIN_DIR}"
			else
				_echo "common_variables.lib copied to ${BIN_DIR}"
			fi
			$CHMOD 644 ${BIN_DIR}/common_variables.lib
			webserver status > /dev/null 2>&1
			if [ $? -eq 1 ] ; then
				_echo "Starting Tomcat ..."
				result=$(webserver start)
			else
				_echo "Restarting Tomcat ..."
				result=$(webserver restart)
			fi
			webserver status > /dev/null 2>&1
			res=$?
			if [ ${res} -ne 0 ] ; then
				_echo "Tomcat failed to start:"
				_echo "Reason : ${result}" 
			fi
		else
			_echo "Tomcat is already configured for SSL"
		fi
		exit 0
	else
		pre_javainstall
		install_java
		post_javainstall
		install_ant
		install_tomcat
		update_versiondb
	fi
else
	pre_javainstall
	install_java
	post_javainstall
	install_ant
	install_tomcat
	update_versiondb
fi

# If it is just an initial install then disable tls renegotiation
if [ ${UPGRADE} == "false" ] ; then
	set_tls_renegotiation
fi
_echo "Runtime successfully installed."

# Calling update_java_security.bsh for EQEV-45618 
#Removing the script calling as in Linux jdk bundle ucrypto-solaris.cfg doesnot exist and logging configuration is working fine 
# $CP bin/update_java_security.bsh ${BIN_DIR}/
# $CHMOD ug+x ${BIN_DIR}/update_java_security.bsh
# _echo "Updating java security..."
# $BASH ${BIN_DIR}/update_java_security.bsh
# if [ $? != 0 ] ; then
	# _echo "Java security not updated"
# else
	# _echo "Java security updated"
# fi

exit 0
