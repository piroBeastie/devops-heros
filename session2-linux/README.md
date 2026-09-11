## Difference B/W Soft Link And Hard Link

- soft link points to the file name/path, hard link points to the inode of the file
- if the original file is deleted, soft link breaks but hard link still has the data
- hard link can't be made for a directory, soft link can

**soft link :** ln -s target linkName

**hard link :** ln target linkName

**delete link :** rm linkName (or unlink linkName)

### practice

```
$ echo "Hello from the original file" > original.txt
$ ln -s original.txt soft_link.txt
$ ln original.txt hard_link.txt
$ ls -li
13742 -rw-r--r-- 2 nanak nanak 29 Sep  4 17:33 hard_link.txt
13742 -rw-r--r-- 2 nanak nanak 29 Sep  4 17:33 original.txt
13764 lrwxrwxrwx 1 nanak nanak 12 Sep  4 17:33 soft_link.txt -> original.txt

$ rm original.txt
$ cat soft_link.txt
cat: soft_link.txt: No such file or directory
$ cat hard_link.txt
Hello from the original file

$ rm soft_link.txt hard_link.txt
```

hard link has the same inode number (13742) as original, soft link has a different one. after deleting original the soft link stopped working but hard link still showed the content.

### interview question

**Q: difference between soft link and hard link?**

hard link is another name for the same inode so data stays even if original is deleted. soft link is like a shortcut which stores the path, so it breaks when original is deleted. hard links only work in same filesystem and not for directories.


## adduser vs useradd

useradd is a low level binary command. it just creates the user entry, by default it does not create home directory, does not set password and gives /bin/sh shell. we have to pass flags like -m, -s for that.

adduser is a script (perl) which uses useradd internally. it is interactive, it creates the home directory, copies files from /etc/skel, creates a group and asks for password.

on ubuntu **adduser is preferred** for creating users manually because it does everything with proper defaults. useradd is better in scripts/automation because it doesn't ask anything.

### created test user

```
$ sudo useradd testuser_useradd
$ sudo adduser --disabled-password --gecos '' testuser_adduser
info: Adding user `testuser_adduser' ...
info: Selecting UID/GID from range 1000 to 59999 ...
info: Adding new group `testuser_adduser' (1003) ...
info: Adding new user `testuser_adduser' (1003) with group `testuser_adduser (1003)' ...
info: Creating home directory `/home/testuser_adduser' ...
info: Copying files from `/etc/skel' ...
info: Adding new user `testuser_adduser' to supplemental / extra groups `users' ...
info: Adding user `testuser_adduser' to group `users' ...

$ tail -2 /etc/passwd
testuser_useradd:x:1001:1002::/home/testuser_useradd:/bin/sh
testuser_adduser:x:1003:1003:,,,:/home/testuser_adduser:/bin/bash

$ ls -ld /home/testuser_useradd
ls: cannot access '/home/testuser_useradd': No such file or directory
```

user made with useradd has no home directory and /bin/sh, user made with adduser got home directory and /bin/bash.


## journalctl

journalctl is used to see the logs collected by systemd. all the system logs, service logs, kernel logs are stored at one place and journalctl is used to read them.

View all logs : journalctl

Last n logs : journalctl -n 10

Watch logs live : journalctl -f

Check a specific service : journalctl -u service

Logs of current boot : journalctl -b

Only errors : journalctl -p err

### checking logs for a service

```
$ journalctl -u cron.service -n 4 --no-pager
Sep 04 17:33:33 Legion systemd[1]: Started cron.service - Regular background program processing daemon.
Sep 04 17:33:33 Legion (cron)[168]: cron.service: Referenced but unset environment variable evaluates to an empty string: EXTRA_OPTS
Sep 04 17:33:33 Legion cron[168]: (CRON) INFO (pidfile fd = 3)
Sep 04 17:33:33 Legion cron[168]: (CRON) INFO (Running @reboot jobs)

$ journalctl --disk-usage
Archived and active journals take up 451.9M in the file system.
```


## Linux Cheat Sheet

practiced the commands from the cheat sheet

| command | use |
|---|---|
| pwd | show current directory |
| ls -la | list all files with details |
| cd | change directory |
| mkdir -p | make directory |
| touch | create empty file |
| cp / mv / rm | copy, move/rename, delete |
| cat / head / tail | read file |
| grep | search text in file |
| find | find files |
| chmod / chown | change permissions / owner |
| df -h | disk usage |
| du -sh | size of folder |
| free -h | memory usage |
| ps aux / top | running processes |
| kill | stop a process |
| tar -czf | make archive |
| whoami / hostname | current user / machine name |

```
$ df -h
Filesystem      Size  Used Avail Use% Mounted on
/dev/sdd       1007G  2.2G  954G   1% /

$ free -h
               total        used        free      shared  buff/cache   available
Mem:           7.6Gi       605Mi       6.7Gi       3.5Mi       441Mi       7.0Gi
Swap:          2.0Gi          0B       2.0Gi
```
