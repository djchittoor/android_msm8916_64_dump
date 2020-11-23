# Copyright (c) 2016 Qualcomm Technologies, Inc.
# All Rights Reserved.
# Confidential and Proprietary - Qualcomm Technologies, Inc.

function Init()
{
	cfglink="/data/usf/proximity/usf_proximity.cfg"
	value=`ls -l $cfglink`
	orgcfgfile=`echo "$value" | tr -s ' '| cut -d' ' -f8`
	local curfile=`echo $orgcfgfile | grep -o "[^/]*$"`
	local cfgdir=`echo $orgcfgfile | sed -r "s/(.*)\/[^\/]+$/\1/"`
	local ext=`echo $curfile |sed -r "s/^usf_proximity_(apps_|tester_)?(.*)$/\2/"`
	reccfg=`echo "$cfgdir/usf_proximity_apps_$ext"`
	testercfg=`echo "$cfgdir/usf_proximity_tester_$ext"`
	forcecfg=`getprop persist.sys.usf.force_using_cfg`

	
	echo "checking if the recording cfg exists" 
	if [ ! -f $reccfg ] 
	then
		echo "Recording cfg file does not exist"
		exit
	fi
	algofilekey="usf_algo_transparent_data_file"
	portscountkey="usf_tx_port_count"
	recfilekey="usf_frame_file"

	algocfgfile=`sed -n -E -r "s/^[[:space:]]*${algofilekey}[[:space:]]+\[(.*)\][[:space:]]*$/\1/pi" $reccfg`
	if [ -f $algocfgfile ] 
	then
		echo "algo data file was found $algocfgfile "
	else
		echo "could not find algo file"
		exit
	fi
	recfile=`sed -n -E -r "s/^[[:space:]]*${recfilekey}[[:space:]]+\[(.*)\][[:space:]]*$/\1/pi" $reccfg`
	if [ -z "$recfile" ]
	then
		echo "Could not find recording file "
		exit
	fi
	recfile="/data/usf/proximity/rec/$recfile";
	nummics=`sed -n -E -r "s/^[[:space:]]*${portscountkey}[[:space:]]+\[(.*)\][[:space:]]*$/\1/pi" $reccfg`
	if [ $nummics -ge 1 ] 
	then
		echo "Number of Microphones is $nummics "
	else
		echo "Could not find Number of microphones"
		exit
	fi
	testerRecordKey="usf_tester_record"
	calibRecordKey="usf_calib_record"	
	lasttesterfile="/data/usf/proximity/tester_record"
	lastcalibfile="/data/usf/proximity/calib_record"
	#checking for tester recording file position
	tmp1=`sed -n -E -r "s/^[[:space:]]*${testerRecordKey}[[:space:]]+\[(.*)\][[:space:]]*$/\1/pi" $reccfg`
	if [ ! -z $tmp1 ]
	then
		lasttesterfile=$tmp1
	fi
	#checking for calib recording file position
	tmp1=`sed -n -E -r "s/^[[:space:]]*${calibRecordKey}[[:space:]]+\[(.*)\][[:space:]]*$/\1/pi" $reccfg`
	if [ ! -z $tmp1 ]
	then
		lastcalibfile=$tmp1
	fi	
	echo "Tester recording location is $lasttesterfile"
	echo "Calibration recording location is $lastcalibfile"
}
function ChangeCfg()
{
	rm -f $cfglink
	ln -s $1 $cfglink
	setprop persist.sys.usf.force_using_cfg 1
}
function RestoreCfg()
{
	setprop persist.sys.usf.force_using_cfg "$forcecfg"
	rm -f $cfglink 
	ln -s $orgcfgfile $cfglink
}
function StartRecord()
{
	rm -f /data/usf/proximity/rec/* 
	echo "start" > /data/usf/proximity/cmd	
}
function StopRecord()
{
	echo "stop" > /data/usf/proximity/cmd
}
function ValidateRecordedFile()
{
	if [ -f $recfile ] 
	then
		echo "algo recorded file was found $recfile "
	else
		echo "could not find recorded file"
		exit
	fi
}
function PrintUsageString()
{
	echo ""
	echo "Usage $0 <Tester|Calibrate|All>"
	echo "\t Tester:Tester only"
	echo "\t Calibrate:Calibration only"
	echo "\t All:Tester and Calibration"	
	echo ""
}
function BackUpAlgoFile()
{
	filename=$(basename "$algocfgfile")
	extension="${filename##*.}"
	filename="${filename%.*}"
	dirname1=$(dirname "$algocfgfile")
	counter=0
	#loop until a new file is found 
	while [ -f "${dirname1}/${filename}_old${counter}.$extension" ]
	do	
		counter=$((counter+1))
	done
	local newsvdfile="${dirname1}/${filename}_old${counter}.$extension"
	cp -f "$algocfgfile" "$newsvdfile"
	echo $newsvdfile
}

function Calibrate()
{
	echo "Changing to the recording configuration"
	ChangeCfg $reccfg
	echo -n "Verify that nothing blocks the earpiece and press [enter]:"
	read 	
	echo "Recording"
	sleepaddition=.38
	sleeptime=2 # number of seconds to sleep or record	
	StartRecord 
	sleep "$sleeptime$sleepaddition"
	StopRecord
	echo "restoring original configurations"
	RestoreCfg

	echo "searching for the algo and recorded data"
	ValidateRecordedFile
	#backing up algo file
	newsvdfile=$( BackUpAlgoFile )
	echo "Configuration backed up in $newsvdfile"

	tmpres=`ls -l $recfile`
	tmp1=`echo "$tmpres" | tr -s ' '`
	size1=`echo "$tmp1" | tr -s ' '| cut -d' ' -f4`
	echo "Checking for the recorded file validity"
	# check for file length
	#echo $((sleeptime*(1024*2*2+12)*192000/1024))
	diff=$((sleeptime*(1024*2*nummics+12)*192000/1024 - size1))
	if [ $diff -lt 0 ]
	then
		diff=$((-1*diff))
	fi
	if [ $diff -gt $((386250/2*nummics+386250/2*(nummics-1))) ]
	then
		echo "something wrong with the recorded file. file length does not match"
		exit
	fi
	# check for data see if it matches current timestamp
	current=`date +%s`
	last_modified=`stat -c "%Y" $recfile`
	diff=$(($current-$last_modified))
	if [ $diff -lt 0 ]
	then
		diff=$((-1*diff))
	fi
	if [ $diff -gt 30 ]
	then
		echo "something wrong with the recorded file. file time does not match"
		exit
	fi
	echo "Moving recorded file to another location $lastcalibfile"
	mv -f $recfile $lastcalibfile 
	echo "Running the calibration"
	#CalibExec="/system/bin/Proximity_calib"
	/system/bin/Proximity_calib $lastcalibfile $newsvdfile /ntasdfasdf $algocfgfile
	calibres=$?
	if [ $calibres -eq 0 ]
	then
		echo "calibration successful"
	else
		echo "calibration failed"
		exit
	fi
}
function Tester()
{
	echo "Generating tester cfg"
	cfgpath=`echo  "$algocfgfile" | sed -n 's/^[[:space:]]*\(\/\([^/]*\/\)\{1,\}\).*/\1/pi'`
	testeralgofile=`echo ${cfgpath}testercalib.dat`
	testeralgofilereg=`echo $testeralgofile | sed 's,/,\\\/,g'`
	tmp1=`echo "s/^\([[:space:]]*${algofilekey}[[:space:]]\{1,\}\)\[.*\]/\1[$testeralgofilereg]/g"`	
	sed "$tmp1" $reccfg > $testercfg	
	csvout="/data/usf/proximity/testerdata.csv"
	sleeptime=3 # number of seconds to sleep or record
	res=$?
	if [ $res -ne 0 ]
	then
		echo ''
		echo "Error generating tester cfg"
		exit	
	fi	
	echo "Generating tester algo"
	/system/bin/Proximity_tester GenTesterCalib $algocfgfile $testeralgofile
	res=$?
	if [ $res -ne 0 ]
	then
		echo ''
		echo "Error generating tester algo file"
		exit	
	fi	
	echo "Changing to the recording configuration"
	ChangeCfg $testercfg
	sleepaddition=.38
	lastcalibfile="/data/usf/proximity/calib_record"
	echo -n "Verify that nothing blocks the earpiece and press [enter]"
	read 
	echo "Recording"		
	StartRecord
	sleep "$sleeptime$sleepaddition"
	echo -n "Cover the earpiece with business-card and press [enter]"
	read 	
	echo "Recording"		
	sleep "$sleeptime$sleepaddition"
	StopRecord
	echo "restoring original configurations"
	RestoreCfg	
	echo "searching for the algo and recorded data"
	ValidateRecordedFile
	#backing up algo file
	newsvdfile=$( BackUpAlgoFile )
	echo "Configuration backed up in $newsvdfile"
	echo "Moving recorded file to another location $lasttesterfile"
	mv -f $recfile $lasttesterfile
	rm -f $csvout
	/system/bin/Proximity_tester TestRec $lasttesterfile $newsvdfile $algocfgfile $csvout 
	testerres=$?	
	if [ -f $csvout ]
	then
		echo "Tester data saved in $csvout"
	fi
	if [ $testerres -eq 0 ]
	then
		echo "Tester successful"
	else
		echo "Tester failed"
		exit
	fi	
	
}
#parsing here inputs
Scripts2Run=3
if [ $# -eq 1 ]
then
	#convert to lower case
	param1=`echo $1 | sed -e 'y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/'`
	case $param1 in
		"all")
		Scripts2Run=3
		;;
		"tester")
		Scripts2Run=1
		;;
		"calibrate")
		Scripts2Run=2
		;;
		*)
			PrintUsageString
			exit
			;;
	esac
else
	PrintUsageString
	exit
fi
#initialize
echo "Initializing"
Init
#select what to run
#Tester
v=$((Scripts2Run & 1))
if [ $v -eq 1 ]
then
	echo "Running Tester"
	Tester
fi
#Calibrator
v=$((Scripts2Run & 2))
if [ $v -eq 2 ]
then
	echo "Running calibration"
	Calibrate
fi
