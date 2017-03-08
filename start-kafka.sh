#!/bin/bash

source /etc/profile

DIRNAME=`dirname $0`
RUNHOME=`cd $DIRNAME/;pwd`

APP_PACKAGE=`basename $RUNHOME/*.tgz`
APP_FOLDER=${APP_PACKAGE%.tgz*}
APP_PATH=$RUNHOME/$APP_FOLDER

APP_NAME=kafka
APP_PORT=9092

LOGS_DIR=$RUNHOME/logs
LOG_FILE=${APP_NAME}.log
PID_FILE=${APP_NAME}.pid

check_status()
{
	check_process_port_and_name $APP_PORT $APP_NAME
	if [ $status -eq 1 ];then
		echo "---$APP_NAME is already running---"
		exit 0
	fi
}

check_java()
{
	if [ -z "$JAVA_HOME" ];then
		echo -e "---the env parameter \"JAVA_HOME\" is not setted.---"
		exit 1
	elif [ ! -d $JAVA_HOME ];then
		echo -e "---the env parameter \"JAVA_HOME\" is not setted correctly.---"
		exit 1
	fi
}

check_zookeeper()
{
	# use the same zookeeper with hbase
	port_status=$(lsof -i :2181 | grep LISTEN | grep -v grep | wc -l)
	if [ $port_status -eq 0 ];then
		echo "---zookeeper is not running, please check---"
		exit 1
	fi
}

untar_package()
{
	cd $RUNHOME
	tar -zxf $APP_PACKAGE
}

create_log()
{
	if [ ! -d $LOGS_DIR ];then
    		mkdir $LOGS_DIR
	else
		rm -rf $LOGS_DIR/*
  	fi

	echo ===================RUN INFO=============== > $LOGS_DIR/$LOG_FILE
  	echo  @RUNHOME@ $RUNHOME >> $LOGS_DIR/$LOG_FILE
	echo  @APP_PACKAGE@ $APP_PACKAGE >> $LOGS_DIR/$LOG_FILE
	echo  @APP_FOLDER@ $APP_FOLDER >> $LOGS_DIR/$LOG_FILE
	echo  @APP_PATH@ $APP_PATH >> $LOGS_DIR/$LOG_FILE
	
	echo  @APP_NAME@ $APP_NAME >> $LOGS_DIR/$LOG_FILE
	echo  @APP_PORT@ $APP_PORT >> $LOGS_DIR/$LOG_FILE
  	echo  ============================================ >> $LOGS_DIR/$LOG_FILE
}

start_app()
{
	SLEEP_NUM=6
	SLEEP_TIME=5

	chmod a+x $APP_PATH/bin/kafka-server-start.sh
	nohup $APP_PATH/bin/kafka-server-start.sh $APP_PATH/config/server.properties >> $LOGS_DIR/$LOG_FILE 2>&1 &

	echo "---starting $APP_NAME, please wait---"
	
	bStart=0	
	for n in $(seq $SLEEP_NUM);do		
		sleep $SLEEP_TIME

		process_status=$(ps -ef | grep $APP_NAME | grep -v grep | wc -l)
		port_status=$(lsof -i :$APP_PORT | grep LISTEN | grep -v grep | wc -l)
		if [ ! $process_status -eq 0 ] && [ ! $port_status -eq 0 ];then
			pid=$(lsof -i :$APP_PORT | grep LISTEN | grep -v grep | awk '{print $2}')
			if [ ! -z $pid ];then
				echo "---$APP_NAME start sucessfully, pid=$pid, port=$APP_PORT---"
				echo $pid > $LOGS_DIR/$PID_FILE

				bStart=1
				break
			fi
		fi
	done
	
	if [ $bStart -eq 0 ];then
		echo "---$APP_NAME failed to start, please check logs for reason---"
	fi	
}

create_topic()
{	
	check_process_port_and_name $APP_PORT $APP_NAME
	if [ $status -eq 1 ];then
		chmod a+x $APP_PATH/bin/kafka-topics.sh
		topic_list=`$APP_PATH/bin/kafka-topics.sh --list --zookeeper localhost:2181`

		need_topics=(tcpmeta udpstat udpspan policy_event result_event NFVMessage)
		for topic in ${need_topics[@]};do
			topic_status=$(echo $topic_list | grep $topic | wc -l)
			if [ $topic_status -eq 0 ];then
				$APP_PATH/bin/kafka-topics.sh --create --zookeeper localhost:2181 --replication-factor 1 --partitions 1 --topic $topic 
			fi
		done	
	
		echo "--- all topics as follows: ---"
		$APP_PATH/bin/kafka-topics.sh --list --zookeeper localhost:2181
	fi
}

check_process_port_and_name()
{
	# 1---ok 0---ng
	port_status=$(lsof -i :$1 | grep LISTEN | grep -v grep | wc -l)
	if [ ! $port_status -eq 0 ];then
		pid=$(lsof -i :$1 | grep LISTEN | grep -v grep | awk '{print $2}')
		process_status=$(ps -ef | grep $pid | grep $2 | grep -v grep | wc -l)
		if [ ! $process_status -eq 0 ];then
			status=1
		else
			status=0
		fi
	else
		status=0
	fi
}


check_status
check_java
check_zookeeper
untar_package
create_log
start_app
create_topic
