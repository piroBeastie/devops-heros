Name : Nanakjot Singh Chahal

Enrollment No : 24bcs10132

## Multi-Stage Dockerfile

stage 1 (builder) installs all packages, stage 2 (production) only copies package.json and server.js from the builder and installs only production dependencies. so the final image doesn't have the extra build stuff.

## Build and Run

app runs on port 3000 inside the container so i mapped it to 8080

```
$ docker build -t multistage-app .

$ docker run -d --name multistage-app -p 8080:3000 multistage-app
59790047f4260fb282392813cf7279ba2e0cd91a31543db3d18f453731fd896f
```

## Output

```
$ curl http://localhost:8080
<h1>Hello World from Docker Multi-Stage Build!</h1>

$ docker logs multistage-app

> docker-hello-world@1.0.0 start
> node server.js

Server running on port 3000
```

## docker ps

```
$ docker ps
CONTAINER ID   IMAGE            COMMAND                  CREATED         STATUS         PORTS                                         NAMES
59790047f426   multistage-app   "docker-entrypoint.s…"   5 seconds ago   Up 5 seconds   0.0.0.0:8080->3000/tcp, [::]:8080->3000/tcp   multistage-app
```

container is running and port 8080 is mapped to 3000.

## Deployed Applications

deployed nodejs, python and java apps (and apache, react, nginx) using docker, code is in [session6-hw](../../session6-hw)

```
$ docker ps
NAMES            IMAGE                STATUS          PORTS
nginx-app        nginx-app            Up 6 seconds    0.0.0.0:3006->80/tcp, [::]:3006->80/tcp
react-app        react-app            Up 6 seconds    0.0.0.0:3005->80/tcp, [::]:3005->80/tcp
apache-app       apache-app           Up 6 seconds    0.0.0.0:3004->80/tcp, [::]:3004->80/tcp
java-app         java-app             Up 7 seconds    0.0.0.0:3003->8080/tcp, [::]:3003->8080/tcp
python-app       python-app           Up 7 seconds    0.0.0.0:3002->5000/tcp, [::]:3002->5000/tcp
nodejs-app       nodejs-app           Up 8 seconds    0.0.0.0:3001->3000/tcp, [::]:3001->3000/tcp
```
