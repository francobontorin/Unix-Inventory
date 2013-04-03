#!/bin/ksh
################################################################################
#
# Documentation
# ==============================================================================
# This script is used to generate an inventory of the Unix servers generaating a
# comprehensive csv report
# ==============================================================================
#
# Version Control
# ==============================================================================
#	Ver 1.0.0 - Created by Franco Bontorin
#			  - Date: Feb 2013
################################################################################


##########################
# VARIABLE DECLARATION   #
##########################

PLATFORM=$(uname)
HOSTNAME=$(uname -n)

function netmask_h2d {
	
	# Convert Solaris Netmask from HEX to DEC
	set -- `echo $1 | sed -e 's/\([0-9a-fA-F][0-9a-fA-F]\)/\1\ /g'`
	perl -e '$,=".";print 0x'$1',0x'$2',0x'$3',0x'$4
}

##################
# MAIN FUNCTIONS #
##################


function GatherInformation {

	# GLOBAL VARIABLES
	
		/usr/seos/bin/seversion > /tmp/seversion_output 2>&1
		ACX=$(cat /tmp/seversion_output | awk '/Access/ {print $5}')		
		[[ -z "$ACX" ]] && ACX=$(cat /tmp/seversion_output | awk '/seversion/ {print $3}' | head -1)
		[[ -z "$ACX" ]] && ACX=NA

	case $PLATFORM in
	
	(AIX)
	
	# GENERAL SERVER INFORMATION
	
		OS_LEVEL=$(oslevel -s)
		/usr/sbin/prtconf > /tmp/prtconf_output 2> /dev/null
		SYSTEM_MODEL=$(awk '/System Model:/ {print $3}' /tmp/prtconf_output | sed 's/,/ /') 
		PROCESSORS=$(awk '/Number Of Processors:/ {print $4}' /tmp/prtconf_output) 
		CORES=$(iostat | awk '/lcpu/ {print $3}' | awk -F '=' '{print $2}')
		CLOCK=$(awk '/Processor Clock Speed:/ {print $4}' /tmp/prtconf_output) 
		CPU_TYPE=$(awk '/CPU Type:/ {print $3}' /tmp/prtconf_output) 
		MEMORY=$(svmon -G | awk ' /memory/ {printf ("%5.2f",$2/256/1024)}'| sed 's/ //g') 
		SWAP=$(svmon -G | awk ' /pg space/ {printf ("%5.2f",$3/256/1024)}'| sed 's/ //g') 
								
	# NETWORK SETTINGS
		
		IP_ADDRESS=$(awk '/IP Address:/ {print $3}' /tmp/prtconf_output) 
		SUBNET=$(awk '/Sub Netmask:/ {print $3}' /tmp/prtconf_output) 
		GATEWAY=$(awk '/Gateway:/ {print $2}' /tmp/prtconf_output) 
				
	# SOFTWARE
			
		ODM_VERSION=$(lslpp -L| awk '/EMC.*aix.rte/ {print $2}' | sort -rn | head -1)
		POWERPATH=$(powermt version | awk '{print $7$8$9$10$11}')
		[[ -z "$POWERPATH" ]] && POWERPATH=NA
		
	# PRINT RESULTS
	
		printf "$HOSTNAME;$PLATFORM;$OS_LEVEL;$SYSTEM_MODEL;$PROCESSORS;$CORES;$CLOCK MHz;$MEMORY GB;$SWAP GB;$IP_ADDRESS;$SUBNET;$GATEWAY;$ODM_VERSION;$POWERPATH;$ACX\n"
	;;
	
	(Linux)
	
	# GENERAL SERVER INFORMATION
	
		OS_LEVEL=$(uname -r)
		SYSTEM_MODEL=$(dmidecode -t system | awk '/Manufacturer:/ {print $2$3}' | sed 's/,/ /' 2> /dev/null)
		PROCESSORS=$(grep -c ^processor /proc/cpuinfo)
		CLOCK=$(awk '/MHz/ {print $4}' /proc/cpuinfo | head -1)
		MEMORY=$(free -g | awk '/Mem:/ {print $2}')
		SWAP=$(free -g | awk '/Swap/ {print $2}')
			
	# NETWORK SETTINGS
		
		IP_ADDRESS=$(grep -w $HOSTNAME /etc/hosts | grep -v ^# | head -1 | awk '{print $1}')
		SUBNET=$(ifconfig -a | grep -w $IP_ADDRESS | awk -F ':' '{print $4}')
		GATEWAY=$(netstat -nr | awk '/^0.0.0.0/ {print $2}' | head -1)
				
	# PRINT RESULTS
	
		printf "$HOSTNAME;$PLATFORM;$OS_LEVEL;$SYSTEM_MODEL;$PROCESSORS;$CLOCK MHz;$MEMORY GB;$SWAP GB;$IP_ADDRESS;$SUBNET;$GATEWAY;$ACX\n"
		
	;;
	
	(SunOS)
	
	# GENERAL SERVER INFORMATION
	
		OS_LEVEL=$(uname -v | awk -F'_' '{print $2}')
		
		SYSTEM_MODEL=$(prtdiag -v 2> /dev/null | awk '/System Configuration/ {print $6,$7,$8}'); [[ -z "$SYSTEM_MODEL" ]] && SYSTEM_MODEL=$(prtconf 2> /dev/null | sed '5!d' | sed 's/,/ /')
		PROCESSORS=$(psrinfo -p)
		CORES=$(kstat cpu_info | grep core_id | uniq | wc -l | sed 's/ //g'); [[ "$CORES" == "0" ]] && CORES=$(psrinfo -pv | head -1 | nawk '{sub(/.*has /,"");sub(/ virtual.*/,"");print;}')
		CLOCK=$(kstat cpu_info | grep clock_MHz | head -1 | awk '{print $2}')
		MEMORY=$(prtconf | awk '/Memory/ {printf ("%5.0f\n", $3/1024)}' | sed 's/ //g')
		USED_SWAP=$(swap -s | awk '{print $9}' | cut -dk -f1 | awk '{printf ("%5.0f \n",$1/1000/1000)}' | sed 's/ //g')
		FREE_SWAP=$(swap -s | awk '{print $11}' | cut -dk -f1 | awk '{printf ("%5.0f \n",$1/1000/1000)}' | sed 's/ //g')
		((SWAP = USED_SWAP + FREE_SWAP))
					
	# NETWORK DETAILS
	
		IP_ADDRESS=$(grep -w $HOSTNAME /etc/hosts | grep -v ^# | head -1 | awk '{print $1}')
		SUBNET_HEX=$(ifconfig -a | awk "/$IP_ADDRESS/" | awk '{print $4}')
		SUBNET=$(netmask_h2d $SUBNET_HEX)
		GATEWAY=$(netstat -nr | awk '/default/ {print $2}' | head -1)
		
	# SOFTWARE
	
		POWERPATH=$(pkginfo -l EMCpower 2> /dev/null | awk /'VERSION/ {print $2}')
		[[ -z "$POWERPATH" ]] && POWERPATH=NA
			
	# PRINT RESULTS
	
		printf "$HOSTNAME;$PLATFORM;$OS_LEVEL;$SYSTEM_MODEL;$PROCESSORS;$CORES;$CLOCK MHz;$MEMORY GB;$SWAP GB;$IP_ADDRESS;$SUBNET;$GATEWAY;$POWERPATH;$ACX\n"
		
	;;
	
	esac
	
	}
	
##########
#  MAIN  #
##########

	GatherInformation
