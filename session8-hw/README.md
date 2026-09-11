# Session 8 - Docker Networking and Volumes

## Task 1: Container Networking

created 3 networks and 3 containers. frontend and backend are nginx, database is mysql. backend is in 2 networks (frontend-net and backend-net) so it can talk to both frontend and database.

```
$ docker network create frontend-net
$ docker network create backend-net
$ docker network create db-net

$ docker run -d --name frontend --network frontend-net nginx:alpine
$ docker run -d --name backend --network frontend-net nginx:alpine
$ docker network connect backend-net backend
$ docker run -d --name database --network backend-net -e MYSQL_ROOT_PASSWORD=root123 mysql:8
$ docker network connect db-net database
```

```
$ docker network ls
NETWORK ID     NAME           DRIVER    SCOPE
5c7aa965f151   backend-net    bridge    local
3051d0730b61   bridge         bridge    local
d09d7249fe7d   db-net         bridge    local
44ee20fe99f0   frontend-net   bridge    local
ccaedb46b908   host           host      local
5eadabe14c3d   none           null      local

$ docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
NAMES            IMAGE            STATUS
database         mysql:8          Up 31 seconds
backend          nginx:alpine     Up 31 seconds
frontend         nginx:alpine     Up 32 seconds

$ docker inspect backend -f '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}'
backend-net frontend-net
```

### checking connectivity

```
$ docker exec frontend ping -c 2 backend
PING backend (172.18.0.3): 56 data bytes
64 bytes from 172.18.0.3: seq=0 ttl=64 time=0.056 ms
64 bytes from 172.18.0.3: seq=1 ttl=64 time=0.070 ms

--- backend ping statistics ---
2 packets transmitted, 2 packets received, 0% packet loss

$ docker exec backend ping -c 2 database
PING database (172.19.0.3): 56 data bytes
64 bytes from 172.19.0.3: seq=0 ttl=64 time=0.066 ms
64 bytes from 172.19.0.3: seq=1 ttl=64 time=0.060 ms

--- database ping statistics ---
2 packets transmitted, 2 packets received, 0% packet loss

$ docker exec frontend ping -c 2 database
ping: bad address 'database'
```

frontend can reach backend and backend can reach database, but frontend can't reach database because they are not in the same network.


## Task 2: Host Network

```
$ docker pull httpd
$ docker run -d --name apache-host --network host httpd

$ docker ps --filter name=apache-host --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
NAMES         STATUS         PORTS
apache-host   Up 4 seconds

$ curl http://localhost:80
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html>
<head>
<title>It works! Apache httpd</title>
</head>
<body>
<p>It works!</p>
</body>
</html>
```

with host network there is no port mapping (PORTS is empty), apache directly uses port 80 of the host.


## Task 3: Bind Mount

```
$ mkdir ~/bind-mount-demo
$ echo '<h1>Hello students</h1>' > ~/bind-mount-demo/index.html

$ docker run -d --name nginx-bind -p 8082:80 -v ~/bind-mount-demo:/usr/share/nginx/html nginx:alpine

$ curl http://localhost:8082
<h1>Hello students</h1>
```

changed the index.html without restarting the container:

```
$ echo '<h1>Hello students - updated</h1>' > ~/bind-mount-demo/index.html

$ curl http://localhost:8082
<h1>Hello students - updated</h1>

$ docker ps --filter name=nginx-bind --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
NAMES        STATUS         PORTS
nginx-bind   Up 4 seconds   0.0.0.0:8082->80/tcp, [::]:8082->80/tcp
```

the change showed up directly because the folder on my machine is mounted inside the container.


## Task 4: Overlay Network

A normal bridge network only works on one docker host. An overlay network is a virtual network that is spread over multiple docker hosts, so containers running on different machines can talk to each other like they are on the same local network. It is mostly used with Docker Swarm, where services run on many nodes and still need to find each other by name.

It works using VXLAN. The container's packet is wrapped inside a UDP packet (port 4789) and sent to the other host over the normal network, and the other host unwraps it and gives it to the right container. Docker keeps track of which container is on which host (in swarm the manager nodes store this). Traffic is not encrypted by default but can be encrypted using `--opt encrypted`.

Use cases:
- containers of one app running on different servers
- docker swarm services and their load balancing (routing mesh)
- keeping some services like database on a separate private network across all nodes

```
docker swarm init
docker network create -d overlay my-overlay
docker service create --name web --network my-overlay --replicas 3 nginx
```
