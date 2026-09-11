# Network Troubleshooting & Verification Commands

commands from the Network-Troubleshooting repo, checked on my machine (ubuntu on wsl)

### 1. Host Identity and Local Network Interfaces

* `hostname`
  * shows the name of my computer on the network

```
$ hostname
Legion
```

* `ip a`
  * shows all network interfaces with their ip address and if they are up or down

```
$ ip -brief address
lo               UNKNOWN        127.0.0.1/8 10.255.255.254/32 ::1/128
eth0             UP             172.31.120.197/20 fe80::215:5dff:fe10:7a60/64
```

---

### 2. Local Socket Statistics and Active Ports

* `ss -tuln`
  * shows which tcp/udp ports are open and listening on my machine. newer tool

```
$ ss -tuln
Netid State  Recv-Q Send-Q  Local Address:Port Peer Address:PortProcess
udp   UNCONN 0      0          127.0.0.54:53        0.0.0.0:*
udp   UNCONN 0      0       127.0.0.53%lo:53        0.0.0.0:*
udp   UNCONN 0      0      10.255.255.254:53        0.0.0.0:*
udp   UNCONN 0      0           127.0.0.1:323       0.0.0.0:*
udp   UNCONN 0      0               [::1]:323          [::]:*
tcp   LISTEN 0      1000   10.255.255.254:53        0.0.0.0:*
tcp   LISTEN 0      4096       127.0.0.54:53        0.0.0.0:*
tcp   LISTEN 0      4096    127.0.0.53%lo:53        0.0.0.0:*
```

* `netstat -tuln`
  * old tool, does the same thing as ss. had to install net-tools for it

```
$ netstat -tuln
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State
tcp        0      0 10.255.255.254:53       0.0.0.0:*               LISTEN
tcp        0      0 127.0.0.54:53           0.0.0.0:*               LISTEN
tcp        0      0 127.0.0.53:53           0.0.0.0:*               LISTEN
udp        0      0 127.0.0.54:53           0.0.0.0:*
udp        0      0 127.0.0.53:53           0.0.0.0:*
udp        0      0 10.255.255.254:53       0.0.0.0:*
udp        0      0 127.0.0.1:323           0.0.0.0:*
udp6       0      0 ::1:323                 :::*
```

---

### 3. ARP Cache

* `arp -a`
  * shows the mapping of ip address to mac address of devices near me. only my gateway is there

```
$ arp -a
Legion.mshome.net (172.31.112.1) at 00:15:5d:12:5d:94 [ether] on eth0
```

---

### 4. Routing Tables

* `route -n`
  * shows the routing table with numbers. 0.0.0.0 with flag UG is the default gateway

```
$ route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         172.31.112.1    0.0.0.0         UG    0      0        0 eth0
172.31.112.0    0.0.0.0         255.255.240.0   U     0      0        0 eth0
```

* `ip route`
  * newer command for the same routing table

```
$ ip route
default via 172.31.112.1 dev eth0 proto kernel
172.31.112.0/20 dev eth0 proto kernel scope link src 172.31.120.197
```

---

### 5. DNS Resolution

* `nslookup google.com`
  * checks if dns can convert google.com into an ip address

```
$ nslookup google.com
Server:		10.255.255.254
Address:	10.255.255.254#53

Non-authoritative answer:
Name:	google.com
Address: 192.178.211.139
Name:	google.com
Address: 192.178.211.100
Name:	google.com
Address: 192.178.211.101
```

* `dig google.com`
  * gives more detail about the dns query like answer section, ttl and query time. `+short` gives only ips

```
$ dig google.com

;; ANSWER SECTION:
google.com.		85	IN	A	192.178.211.101
google.com.		85	IN	A	192.178.211.138
google.com.		85	IN	A	192.178.211.102
google.com.		85	IN	A	192.178.211.113
google.com.		85	IN	A	192.178.211.139
google.com.		85	IN	A	192.178.211.100

;; Query time: 65 msec
;; SERVER: 10.255.255.254#53(10.255.255.254) (UDP)

$ dig +short google.com
192.178.211.102
192.178.211.113
192.178.211.139
192.178.211.100
192.178.211.101
192.178.211.138
```

---

### 6. ICMP Reachability and Path Tracing

* `ping -c 4 google.com`
  * sends 4 packets to check if google is reachable and how much time it takes

```
$ ping -c 4 google.com
PING google.com (192.178.211.139) 56(84) bytes of data.
64 bytes from lcbomp-in-f139.1e100.net (192.178.211.139): icmp_seq=1 ttl=108 time=17.9 ms
64 bytes from lcbomp-in-f139.1e100.net (192.178.211.139): icmp_seq=2 ttl=108 time=23.9 ms
64 bytes from lcbomp-in-f139.1e100.net (192.178.211.139): icmp_seq=3 ttl=108 time=23.6 ms
64 bytes from lcbomp-in-f139.1e100.net (192.178.211.139): icmp_seq=4 ttl=108 time=57.6 ms

--- google.com ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 2998ms
rtt min/avg/max/mdev = 17.894/30.763/57.628/15.694 ms
```

* `traceroute google.com`
  * shows every router (hop) the packet goes through to reach google. `* * *` means that hop didn't reply

```
$ traceroute -m 12 google.com
traceroute to google.com (192.178.211.101), 12 hops max, 60 byte packets
 1  Legion.mshome.net (172.31.112.1)  0.537 ms  0.516 ms  0.506 ms
 2  wifi.height8tech.com (100.128.160.1)  46.139 ms  51.102 ms  42.938 ms
 3  114.79.130.29.dvois.com (114.79.130.29)  66.230 ms  69.672 ms  60.968 ms
 4  72.14.208.165 (72.14.208.165)  52.326 ms  48.428 ms  57.016 ms
 5  192.178.84.175 (192.178.84.175)  42.333 ms 192.178.110.123 (192.178.110.123)  47.051 ms 192.178.110.221 (192.178.110.221)  48.405 ms
 6  192.178.110.248 (192.178.110.248)  50.186 ms 172.253.177.30 (172.253.177.30)  58.015 ms 192.178.242.42 (192.178.242.42)  58.111 ms
 7  * * 192.178.254.221 (192.178.254.221)  37.562 ms
```

---

### 7. Layer 4 TCP Port Connectivity

* `timeout 5 telnet google.com 80`
  * checks if port 80 on google is open. "Connected" means port is open

```
$ timeout 5 telnet google.com 80
Trying 192.178.211.102...
Connected to google.com.
Escape character is '^]'.
Connection closed by foreign host.
```

---

### 8. Layer 7 HTTP/HTTPS Verification

* `curl -I https://www.google.com`
  * gets only the headers from the website, HTTP 200 means website is working

```
$ curl -I https://www.google.com
HTTP/2 200
content-type: text/html; charset=ISO-8859-1
date: Fri, 04 Sep 2026 17:46:38 GMT
server: gws
x-xss-protection: 0
x-frame-options: SAMEORIGIN
cache-control: private
```

---

### 9. Packet Inspection

* `sudo tcpdump -i any -n -c 8 host google.com or icmp`
  * captures live packets going between my machine and google. needs sudo. i ran ping at the same time so it caught the echo request and reply

```
$ sudo tcpdump -i any -n -c 8 'host google.com or icmp'
tcpdump: data link type LINUX_SLL2
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on any, link-type LINUX_SLL2 (Linux cooked v2), snapshot length 262144 bytes
17:51:08.583296 eth0  Out IP 172.31.120.197 > 192.178.211.113: ICMP echo request, id 1570, seq 1, length 64
17:51:08.600673 eth0  In  IP 192.178.211.113 > 172.31.120.197: ICMP echo reply, id 1570, seq 1, length 64
17:51:09.624558 eth0  Out IP 172.31.120.197 > 192.178.211.113: ICMP echo request, id 1570, seq 2, length 64
17:51:09.640554 eth0  In  IP 192.178.211.113 > 172.31.120.197: ICMP echo reply, id 1570, seq 2, length 64
17:51:10.664222 eth0  Out IP 172.31.120.197 > 192.178.211.113: ICMP echo request, id 1570, seq 3, length 64
17:51:10.680572 eth0  In  IP 192.178.211.113 > 172.31.120.197: ICMP echo reply, id 1570, seq 3, length 64
17:51:11.772443 eth0  Out IP 172.31.120.197 > 192.178.211.113: ICMP echo request, id 1570, seq 4, length 64
17:51:11.788404 eth0  In  IP 192.178.211.113 > 172.31.120.197: ICMP echo reply, id 1570, seq 4, length 64
8 packets captured
16 packets received by filter
0 packets dropped by kernel
```

---

### 10. Network Service Status

* `systemctl status systemd-resolved`
  * checks if the dns service is running. wsl doesn't have NetworkManager so i checked this one

```
$ systemctl status systemd-resolved --no-pager
● systemd-resolved.service - Network Name Resolution
     Loaded: loaded (/usr/lib/systemd/system/systemd-resolved.service; enabled; preset: enabled)
     Active: active (running) since Fri 2026-09-04 17:38:17 UTC; 8min ago
   Main PID: 169 (systemd-resolve)
     Status: "Processing requests..."
```
