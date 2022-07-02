#!/bin/bash

# ilo credentials
ILO_IP=""
ILO_USER="Administrator"
ILO_PASSWORD=""

# common settings
hyst=2
# sshpass_path="/mnt/user/appdata"

# cpu 0
cpu_zero_fan_speed=0
prev_cpu_zero_temp=0
prev_cpu_zero_fan_speed=0
cpu_zero_max_speed=255
cpu_zero_temp_steps=(59 80)
cpu_zero_speed_steps=(20 95)

# mb
mb_fan_speed=0
prev_mb_temp=0
prev_mb_fan_speed=0
mb_min_speed=1
mb_max_speed=255
mb_temp_steps=(63 80)
mb_speed_steps=(20 70)

abs() {
    E_ARGERR=-999999
    if [ -z "$1" ]; then
        return $E_ARGERR
    fi
    if [ "$1" -ge 0 ]; then
        absval=$1
    else
        let "absval = (( 0 - $1 ))"
    fi
    return $absval
}

# round ()
# {
#     local temp=$(LC_NUMERIC="en_US.UTF-8" printf "%.0f\n" $1)
#     return "$temp"
# }

cpuZeroControl() {
    local cpu_zero_temp=$(sensors | sed -rn 's/.*Package id 0:\s+.([0-9]+).*/\1/p')
    echo "cpu0 temperature $cpu_zero_temp"
    local temp_diff=$((cpu_zero_temp - prev_cpu_zero_temp))
    abs $temp_diff
    local temp_diff=$?

    if (($temp_diff > $hyst)); then
        if (($cpu_zero_temp < ${cpu_zero_temp_steps[0]})); then
            let "cpu_zero_fan_speed=${cpu_zero_speed_steps[0]}"
        elif (($cpu_zero_temp >= ${cpu_zero_temp_steps[-1]})); then
            let "cpu_zero_fan_speed=$cpu_zero_max_speed"
        else
            for i in "${!cpu_zero_temp_steps[@]}"; do
                let "k=i+1"
                if (($cpu_zero_temp >= ${cpu_zero_temp_steps[$i]})) && (($cpu_zero_temp < ${cpu_zero_temp_steps[$k]})); then
                    let "cpu_zero_fan_speed=(${cpu_zero_speed_steps[$k]}-${cpu_zero_speed_steps[$i]})/(${cpu_zero_temp_steps[$k]}-${cpu_zero_temp_steps[$i]})*($cpu_zero_temp-${cpu_zero_temp_steps[$i]})+${cpu_zero_speed_steps[$i]}"
                fi
            done
        fi
    fi

    if (($cpu_zero_fan_speed != $prev_cpu_zero_fan_speed && (($cpu_zero_fan_speed >= ${cpu_zero_speed_steps[0]}) || ($cpu_zero_fan_speed == 0)))); then
        echo "cpu0 fan speed is $cpu_zero_fan_speed"
        sshpass -p "$ILO_PASSWORD" ssh -oKexAlgorithms=+diffie-hellman-group1-sha1 -o StrictHostKeyChecking=no $ILO_USER@$ILO_IP "fan p 2 max $cpu_zero_fan_speed && exit"
        let "prev_cpu_zero_fan_speed=$cpu_zero_fan_speed"
    fi
}

mb() {
    # local mb_temp=$(sensors | sed -rn 's/.*loc1:\s+.([0-9]+).*/\1/p')
    local mb_temp=$(sensors | sed -rn 's/.*Package id 0:\s+.([0-9]+).*/\1/p')
    local temp_diff=$((mb_temp - prev_mb_temp))
    abs $temp_diff
    local temp_diff=$?

    if (($temp_diff > $hyst)); then
        if (($mb_temp < ${mb_temp_steps[0]})); then
            let "mb_fan_speed=$mb_min_speed"
        elif (($mb_temp >= ${mb_temp_steps[-1]})); then
            let "mb_fan_speed=$mb_max_speed"
        else
            for i in "${!mb_temp_steps[@]}"; do
                let "k=i+1"
                if (($mb_temp >= ${mb_temp_steps[$i]})) && (($mb_temp < ${mb_temp_steps[$k]})); then
                    let "mb_fan_speed=(${mb_speed_steps[$k]}-${mb_speed_steps[$i]})/(${mb_temp_steps[$k]}-${mb_temp_steps[$i]})*($mb_temp-${mb_temp_steps[$i]})+${mb_speed_steps[$i]}"
                fi
            done
        fi
    fi

    if (($mb_fan_speed != $prev_mb_fan_speed && (($mb_fan_speed >= $mb_min_speed) || ($mb_fan_speed == 0)))); then
        echo "mb fan speed is $mb_fan_speed"
        sshpass -p "$ILO_PASSWORD" ssh -oKexAlgorithms=+diffie-hellman-group1-sha1 -o StrictHostKeyChecking=no $ILO_USER@$ILO_IP "fan p 1 max $mb_fan_speed && exit"
        let "prev_mb_fan_speed=$mb_fan_speed"
    fi
}

# if [ $# -ne 3 ]; then
#         echo "please specify 3 command line arguments"
# 		exit 1
# fi

# ILO_IP=$1
# ILO_USER=$2
# ILO_PASSWORD=$3

echo "fan controller has been started"

while :; do
    cpuZeroControl
    mb

    sleep 45
done
