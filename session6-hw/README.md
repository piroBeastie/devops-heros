# Docker Fundamentals HW - Hello World Apps

made hello world web apps for nodejs, python, java, apache, react and nginx. each one has its own folder with the code and a Dockerfile.

| folder | port |
|---|---|
| nodejs-app | 3001 |
| python-app | 3002 |
| java-app | 3003 |
| Apache-app | 3004 |
| React-app | 3005 |
| nginx-app | 3006 |

## Build

```
docker build -t nodejs-app ./nodejs-app
docker build -t python-app ./python-app
docker build -t java-app ./java-app
docker build -t apache-app ./Apache-app
docker build -t react-app ./React-app
docker build -t nginx-app ./nginx-app
```

![Screenshot 1](Screenshot%202026-09-11%20222101.png)

![Screenshot 2](Screenshot%202026-09-11%20222109.png)

![Screenshot 3](Screenshot%202026-09-11%20222115.png)

## Run

```
docker run -d --name nodejs-app -p 3001:3000 nodejs-app
docker run -d --name python-app -p 3002:5000 python-app
docker run -d --name java-app -p 3003:8080 java-app
docker run -d --name apache-app -p 3004:80 apache-app
docker run -d --name react-app -p 3005:80 react-app
docker run -d --name nginx-app -p 3006:80 nginx-app
```

![Screenshot 4](Screenshot%202026-09-11%20221920.png)

## Output

### Node.js - localhost:3001
![Screenshot 5](Screenshot%202026-09-11%20221930.png)

### Python - localhost:3002
![Screenshot 6](Screenshot%202026-09-11%20221941.png)

### Java - localhost:3003
![Screenshot 7](Screenshot%202026-09-11%20221951.png)

### Apache - localhost:3004
![Screenshot 8](Screenshot%202026-09-11%20222002.png)

### React - localhost:3005
![Screenshot 9](Screenshot%202026-09-11%20222012.png)

### Nginx - localhost:3006
![Screenshot 10](Screenshot%202026-09-11%20222023.png)
