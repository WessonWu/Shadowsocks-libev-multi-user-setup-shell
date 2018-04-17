#!/usr/bin/env bash
# chkconfig: 2345 90 10
# description: A secure socks5 proxy, designed to protect your Internet traffic.

### BEGIN INIT INFO
# Provides:          Shadowsocks-libev
# Required-Start:    $network $syslog
# Required-Stop:     $network
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Fast tunnel proxy that helps you bypass firewalls
# Description:       Start or stop the Shadowsocks-libev server
### END INIT INFO

# Author: WessonWu <wessonwu94@gmail.com>
if [ -f /usr/local/bin/ss-server ]; then
    DAEMON=/usr/local/bin/ss-server
elif [ -f /usr/bin/ss-server ]; then
    DAEMON=/usr/bin/ss-server
fi
# 名称
NAME=Shadowsocks-libev
# 配置文件目录
CONF_DIR=/etc/shadowsocks-libev
# 配置文件名后缀
CONF_FILE_SUFFIX=".json"
# 所有的配置文件
CONF_FILES=$(ls $CONF_DIR/*$CONF_FILE_SUFFIX 2>/dev/null)

# pid目录
PID_DIR=/var/run/shadowsocks-libev
# pid文件后缀名
PID_FILE_SUFFIX=".pid"
# 所有的pid文件
PID_FILES=
# 临时的pid
PID=

RET_VAL=0

# 检查是否为可执行文件
[ -x $DAEMON ] || exit 0

# 检查配置文件目录是否存在
if [ ! -d $CONF_DIR ]; then
    echo "Config directory $CONF_DIR not exist."
    exist 1
fi

# 检查pid目录是否存在
if [ ! -d $PID_DIR ]; then
    mkdir -p $PID_DIR
    if [ $? -ne 0 ]; then
        echo "Creating PID directory $PID_DIR failed"
        exit 1
    fi
fi

# 获取配置文件名去掉后缀
get_conf_name() {
    echo "`basename $1 $CONF_FILE_SUFFIX`"
}

# 通过文件名获取pid文件
get_pid_file_with_name() {
    echo "$PID_DIR/$1$PID_FILE_SUFFIX"
}

# 获取配置文件名(通过pid文件)
get_conf_name_with_pid_file() {
    echo "`basename $1 $PID_FILE_SUFFIX`"
}

# 获取配置文件(通过名称)
get_conf_file_with_name() {
    echo "$CONF_DIR/$1$CONF_FILE_SUFFIX"
}

# 获取所有的pid目录下的所有pid文件
get_pid_files() {
    PID_FILES=$(ls $PID_DIR/*$PID_FILE_SUFFIX 2>/dev/null)
}

# 通过pid_file检查是否在运行
check_running_with_pid_file() {
    local pid_file=$1
    if [ -r $pid_file ]; then
        read PID < $pid_file
        if [ -d "/proc/$PID" ]; then
            return 0
        else
            rm -f $pid_file
            return 1
        fi
    else
        return 2
    fi
}

# 根据配置文件查看状态
do_status_with_conf_file() {
    local conf_file=$1
    local conf_name=$(get_conf_name $conf_file)
    local pid_file=$(get_pid_file_with_name $conf_name)
    check_running_with_pid_file $pid_file
    case $? in
        0)
        echo "$NAME (conf: $conf_name, pid: $PID) is running..."
        ;;
        1|2)
        echo "$NAME (conf: $conf_name, pid: $PID) is stopped"
        ;;
    esac
}

# 查看状态
do_status() {
    local conf_file
    for conf_file in $CONF_FILES
    do
        do_status_with_conf_file $conf_file
    done
}

# 通过配置文件启动
do_start_with_conf_file() {
    local conf_file=$1
    local conf_name=$(get_conf_name $conf_file)
    local pid_file=$(get_pid_file_with_name $conf_name)
    # echo "start $conf_file, $conf_name, $pid_file"
    check_running_with_pid_file $pid_file
    if [ $? -eq 0 ]; then
        echo "$NAME (pid $PID) is already running..."
        return 0
    fi

    $DAEMON -uv -c $conf_file -f $pid_file
    check_running_with_pid_file $pid_file
    if [ $? -eq 0 ]; then
        echo "Starting $NAME (conf: $conf_name, pid: $PID) success"
    else
        echo "Starting $NAME (conf: $conf_name) failed"
    fi
}

# 启动
do_start() {
    clean_up_deprecated

    local conf_file
    for conf_file in $CONF_FILES
    do
        do_start_with_conf_file $conf_file
    done
}

# 通过配置文件停止
do_stop_with_conf_file() {
    local conf_file=$1
    local conf_name=$(get_conf_name $conf_file)
    local pid_file=$(get_pid_file_with_name $conf_name)
    
    check_running_with_pid_file $pid_file
    if [ $? -eq 0 ]; then
        expr $PID + 0 &>/dev/null
        # pid是否存在
        if [ $? -eq 0 ]; then
            kill -9 $PID
        fi
        rm -f $pid_file
        echo "Stopping $NAME (conf: $conf_name, pid: $PID) success"
    else
        echo "$NAME (conf: $conf_name) is stopped"
    fi
}

# 停止
do_stop() {
    local conf_file
    for conf_file in $CONF_FILES
    do
        do_stop_with_conf_file $conf_file
    done

    clean_up_deprecated
}

# 清理过时的进程
clean_up_deprecated() {
    local pid_file
    local conf_name
    local conf_file
    get_pid_files
    for pid_file in $PID_FILES
    do
        conf_name=$(get_conf_name_with_pid_file $pid_file)
        conf_file=$(get_conf_file_with_name $conf_name)
        contains_conf_file $conf_file
        if [ $? -ne 0 ]; then
            do_stop_with_conf_file $conf_file
        fi  
    done
}

contains_conf_file() {
    local conf_file=$1
    local tmp_file
    for tmp_file in ${CONF_FILES[@]}
    do
        if [ "$tmp_file" == $"$conf_file" ]; then
            return 0
        fi
    done
    return 1
}

do_restart() {
    do_stop
    do_start
}

case "$1" in
    start|stop|restart|status)
    do_$1
    ;;
    *)
    echo "Usage: $0 { start | stop | restart | status }"
    RET_VAL=1
    ;;
esac

exit $RET_VAL