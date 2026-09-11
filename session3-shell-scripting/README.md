## Shell Scripting HW - System Information Script

script: [task.sh](task.sh)

it prints date, hostname, username, disk usage and running processes. it takes name and roll number using `read -p`, stores values in variables, makes a directory with `mkdir`, a file with `touch` and saves the running processes into the file using `>`.

commands used: `mkdir`, `touch`, `echo`, `df`, `ps`, `read -p`, variables, `>`

## Output

```
$ chmod +x task.sh
$ ./task.sh
Enter your name: Nanakjot Singh Chahal
Enter your roll number: 24bcs10132

Name: Nanakjot Singh Chahal
Roll Number: 24bcs10132

current date: Fri Sep 11 16:25:45 UTC 2026
hostname: Legion
username: nanak

disk usage:
Filesystem      Size  Used Avail Use% Mounted on
none            3.9G     0  3.9G   0% /usr/lib/modules/6.6.87.2-microsoft-standard-WSL2
none            3.9G  4.0K  3.9G   1% /mnt/wsl
drivers         320G  288G   32G  91% /usr/lib/wsl/drivers
/dev/sdd       1007G  6.3G  950G   1% /
none            3.9G   72K  3.9G   1% /mnt/wslg
none            3.9G     0  3.9G   0% /usr/lib/wsl/lib
rootfs          3.8G  2.7M  3.8G   1% /init
none            3.9G  1.2M  3.9G   1% /run
none            3.9G     0  3.9G   0% /run/lock
none            3.9G     0  3.9G   0% /run/shm
none            3.9G   64K  3.9G   1% /mnt/wslg/versions.txt
none            3.9G   64K  3.9G   1% /mnt/wslg/doc
C:\             320G  288G   32G  91% /mnt/c
D:\             634G  384G  251G  61% /mnt/d
tmpfs           3.9G   16K  3.9G   1% /run/user/1000

running processes:
    PID TTY          TIME CMD
   1733 pts/2    00:00:00 task.sh
   1779 pts/2    00:00:00 ps

processes saved in process_info/process.log
total 16
-rw-r--r-- 1 nanak nanak 14500 Sep 11 16:25 process.log
```

checking the file:

```
$ head -5 process_info/process.log
UID          PID    PPID  C STIME TTY          TIME CMD
root           1       0  6 16:25 ?        00:00:00 /sbin/init
root           2       1  0 16:25 ?        00:00:00 /init
root           7       2  0 16:25 ?        00:00:00 plan9 --control-socket 7 --log-level 4 --server-fd 8 --pip
root          58       1  1 16:25 ?        00:00:00 /usr/lib/systemd/systemd-journald
```
