#!/bin/bash

# system info script

curr_date=$(date)
host_name=$(hostname)
user_name=$(whoami)

read -p "Enter your name: " name
read -p "Enter your roll number: " rollNumber

echo
echo "Name: $name"
echo "Roll Number: $rollNumber"
echo

echo "current date: $curr_date"
echo "hostname: $host_name"
echo "username: $user_name"
echo

echo "disk usage:"
df -h
echo

echo "running processes:"
ps
echo

# make directory and file, save processes in the file
mkdir -p process_info
touch process_info/process.log
ps -ef > process_info/process.log

echo "processes saved in process_info/process.log"
ls -l process_info
