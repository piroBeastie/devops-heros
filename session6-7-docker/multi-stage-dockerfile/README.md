Name : Nanakjot Singh Chahal

Enrollment No : 24bcs10132

## Multi-Stage Dockerfile

stage 1 (builder) installs all packages, stage 2 (production) only copies package.json and server.js from the builder and installs only production dependencies. so the final image doesn't have the extra build stuff.

## Build

```
docker build -t multistage-app .
```

![Screenshot 1](Screenshot%202026-09-11%20222125.png)

## Run

app runs on port 3000 inside the container so i mapped it to 8080

```
docker run -d --name multistage-app -p 8080:3000 multistage-app
```

container is running and `docker ps` shows port 8080 mapped to 3000

![Screenshot 2](Screenshot%202026-09-11%20222136.png)

## Output

![Screenshot 3](Screenshot%202026-09-11%20222146.png)

## Deployed Applications

deployed nodejs, python and java apps (and apache, react, nginx) using docker, code and screenshots are in [session6-hw](../../session6-hw)
