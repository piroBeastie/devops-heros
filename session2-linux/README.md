## Difference B/W Soft Link And Hard Link

- soft link points to the file name/path, hard link points to the inode of the file
- if the original file is deleted, soft link breaks but hard link still has the data
- hard link can't be made for a directory, soft link can

**soft link :** ln -s target linkName

**hard link :** ln target linkName

**delete link :** rm linkName (or unlink linkName)

### practice

![Screenshot 1](Screenshot%202026-09-11%20221440.png)

hard link has the same inode number as original, soft link has a different one. after deleting original the soft link stopped working but hard link still showed the content.

### interview question

**Q: difference between soft link and hard link?**

hard link is another name for the same inode so data stays even if original is deleted. soft link is like a shortcut which stores the path, so it breaks when original is deleted. hard links only work in same filesystem and not for directories.


## adduser vs useradd

useradd is a low level binary command. it just creates the user entry, by default it does not create home directory, does not set password and gives /bin/sh shell. we have to pass flags like -m, -s for that.

adduser is a script (perl) which uses useradd internally. it is interactive, it creates the home directory, copies files from /etc/skel, creates a group and asks for password.

on ubuntu **adduser is preferred** for creating users manually because it does everything with proper defaults. useradd is better in scripts/automation because it doesn't ask anything.

### created test user

![Screenshot 2](Screenshot%202026-09-11%20221445.png)

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

![Screenshot 3](Screenshot%202026-09-11%20221450.png)


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

![Screenshot 4](Screenshot%202026-09-11%20221455.png)
