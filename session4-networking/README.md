# Network Troubleshooting & Verification Commands

commands from the Network-Troubleshooting repo, checked on my machine (ubuntu on wsl)

### 1. Host Identity and Local Network Interfaces

* `hostname`
  * shows the name of my computer on the network

* `ip a`
  * shows network interfaces with their ip address and if they are up or down. i showed lo and eth0 because docker made a lot of extra interfaces

![Screenshot 1](Screenshot%202026-09-11%20221749.png)

---

### 2. Local Socket Statistics and Active Ports

* `ss -tuln`
  * shows which tcp/udp ports are open and listening on my machine. newer tool. the 3001-3006 and 8080 ports are from my docker containers

![Screenshot 2](Screenshot%202026-09-11%20221754.png)

* `netstat -tuln`
  * old tool, does the same thing as ss. had to install net-tools for it

![Screenshot 3](Screenshot%202026-09-11%20221759.png)

---

### 3. ARP Cache and Routing Tables

* `arp -a`
  * shows the mapping of ip address to mac address of devices near me. only my gateway is there

* `route -n`
  * shows the routing table with numbers. 0.0.0.0 with flag UG is the default gateway

* `ip route`
  * newer command for the same routing table

![Screenshot 4](Screenshot%202026-09-11%20221550.png)

---

### 4. DNS Resolution

* `nslookup google.com`
  * checks if dns can convert google.com into an ip address

![Screenshot 5](Screenshot%202026-09-11%20221804.png)

* `dig google.com`
  * gives more detail about the dns query like answer section, ttl, which server answered and query time

![Screenshot 6](Screenshot%202026-09-11%20221809.png)

---

### 5. ICMP Reachability and Path Tracing

* `ping -c 4 google.com`
  * sends 4 packets to check if google is reachable and how much time it takes

* `traceroute google.com`
  * shows every router (hop) the packet goes through to reach google. `* * *` means that hop didn't reply

![Screenshot 7](Screenshot%202026-09-11%20221609.png)

---

### 6. Layer 4 and Layer 7 Connectivity

* `timeout 5 telnet google.com 80`
  * checks if port 80 on google is open. "Connected" means port is open. timeout stops it after 5 sec

* `curl -I https://www.google.com`
  * gets only the headers from the website, HTTP 200 means website is working

![Screenshot 8](Screenshot%202026-09-11%20221619.png)

---

### 7. Packet Inspection

* `sudo tcpdump -i any -n -c 8 host google.com or icmp`
  * captures live packets going between my machine and google. needs sudo. i ran ping at the same time so it caught the echo request and reply

![Screenshot 9](Screenshot%202026-09-11%20221631.png)

---

### 8. Network Service Status

* `systemctl status systemd-resolved`
  * checks if the dns service is running. wsl doesn't have NetworkManager so i checked this one

![Screenshot 10](Screenshot%202026-09-11%20221814.png)
