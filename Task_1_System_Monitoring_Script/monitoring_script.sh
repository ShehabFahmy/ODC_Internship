#!/bin/bash

# The user may run the script in different ways, as follows:
# 1) ./script.sh
# 2) ./script.sh -t 80
# 3) ./script.sh -f output.log
# 4) ./script.sh -t 80 -f output.log
# 5) ./script.sh -f output.log -t 80

THRESHOLD=80
LOGS_FILE_NAME="sys_monitor.log"
if [[ $1 == "-t" ]]; then
    THRESHOLD=$2
    if [[ $3 == "-f" ]]; then
        LOGS_FILE_NAME=$4
    fi
elif [[ $1 == "-f" ]]; then
    LOGS_FILE_NAME=$2
    if [[ $3 == "-t" ]]; then
        THRESHOLD=$4
    fi
fi

# Corner Cases
# 1) Remove '%' if the user entered it with the number
lastChar=${THRESHOLD:${#THRESHOLD}-1:1}
if [[ $lastChar == '%' ]]; then
    THRESHOLD=${THRESHOLD:0:${#THRESHOLD}-1}
fi
# 2) Add ".log" to the output file name if not specified
isExtensionExists=$(echo $LOGS_FILE_NAME | grep ".log" | wc -l)
if [[ $isExtensionExists -eq 0 ]]; then
    LOGS_FILE_NAME="${LOGS_FILE_NAME}.log"
fi

# The '>' operator will clear the previous report and starts a new one
echo "System Monitoring Report - `date +"%Y-%m-%d %H:%M:%S"`" > /tmp/${LOGS_FILE_NAME}

# DISK
echo "======================================================" >> /tmp/${LOGS_FILE_NAME}
echo "Disk Usage:" >> /tmp/${LOGS_FILE_NAME}
df >> /tmp/${LOGS_FILE_NAME}
DISK_ALERT=$(df | awk -v THRESHOLD="$THRESHOLD" '{if ($5 > THRESHOLD) print $0; if ($5 > THRESHOLD && $5 ~ /^[0-9]+%$/) print "[!] Warning: " $1 " is above " THRESHOLD "% usage!"}')
DISKS_OVER_THRESHOLD=$(df | awk -v THRESHOLD="$THRESHOLD" '{if ($5 > THRESHOLD && $5 ~ /^[0-9]+%$/) print $1}')
if [ -n $DISKS_OVER_THRESHOLD ]; then
  TO="recipient@gmail.com"
  SUBJECT="Alert: High Disk Usage - `date +"%Y-%m-%d %H:%M:%S"`"
  BODY="$DISK_ALERT"
  echo -e "To: $TO\nSubject: $SUBJECT\n\n$BODY" | ssmtp $TO
fi

# CPU
echo "======================================================" >> /tmp/${LOGS_FILE_NAME}
echo "CPU Usage:" >> /tmp/${LOGS_FILE_NAME}
# CPU Usage (%) = 100 − Idle Time (%)
IDLE_TIME=$(top -b -n1 | grep -i "%cpu(s)" | awk '{print $8}')  # `-b` for batch mode and `-n1` for one iteration only
CPU_USAGE=$(echo "100.0 - $IDLE_TIME" | bc)  # "bc" is used for floating-point arithmetic
echo "Current CPU Usage: ${CPU_USAGE}%" >> /tmp/${LOGS_FILE_NAME}

# MEMORY
echo "======================================================" >> /tmp/${LOGS_FILE_NAME}
echo "Memory Usage:" >> /tmp/${LOGS_FILE_NAME}
echo "Total Memory: $(free -g | grep -i "mem" | awk '{print $2}')GB" >> /tmp/${LOGS_FILE_NAME}
echo "Used Memory: $(free -g | grep -i "mem" | awk '{print $3}')GB" >> /tmp/${LOGS_FILE_NAME}
echo "Free Memory: $(free -g | grep -i "mem" | awk '{print $4}')GB" >> /tmp/${LOGS_FILE_NAME}

# TOP-5 MEMORY-CONSUMING PROCESSES
echo "======================================================" >> /tmp/${LOGS_FILE_NAME}
echo "Top 5 Memory-Consuming Processes:" >> /tmp/${LOGS_FILE_NAME}
echo "$(top -b -o %MEM -n1 | sed -n '7,12p' | awk '{print $1 "\t" $2 "\t" $10 "\t" $12}')" >> /tmp/${LOGS_FILE_NAME}
