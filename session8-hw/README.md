# Session 8 - Docker Networking and Volumes

## Task 1: Container Networking

created 3 networks and 3 containers. frontend and backend are nginx, database is mysql. backend is in 2 networks (frontend-net and backend-net) so it can talk to both frontend and database.

```
docker network create frontend-net
docker network create backend-net
docker network create db-net

docker run -d --name frontend --network frontend-net nginx:alpine
docker run -d --name backend --network frontend-net nginx:alpine
docker network connect backend-net backend
docker run -d --name database --network backend-net -e MYSQL_ROOT_PASSWORD=root123 mysql:8
docker network connect db-net database
```

![Screenshot 1](Screenshot%202026-09-11%20222154.png)

### checking connectivity

![Screenshot 2](Screenshot%202026-09-11%20222202.png)

frontend can reach backend and backend can reach database, but frontend can't reach database because they are not in the same network.


## Task 2: Host Network

```
docker pull httpd
docker run -d --name apache-host --network host httpd
```

![Screenshot 3](Screenshot%202026-09-11%20222213.png)

with host network there is no port mapping (PORTS is empty), apache directly uses port 80 of the host.


## Task 3: Bind Mount

```
mkdir bind-mount-demo
echo '<h1>Hello students</h1>' > bind-mount-demo/index.html
docker run -d --name nginx-bind -p 8082:80 -v ~/bind-mount-demo:/usr/share/nginx/html nginx:alpine
```

![Screenshot 4](Screenshot%202026-09-11%20222222.png)

![Screenshot 5](Screenshot%202026-09-11%20222232.png)

changed the index.html without restarting the container:

![Screenshot 6](Screenshot%202026-09-11%20222238.png)

![Screenshot 7](Screenshot%202026-09-11%20222248.png)

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
