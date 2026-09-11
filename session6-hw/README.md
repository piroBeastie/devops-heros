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
$ docker build -t nodejs-app ./nodejs-app
$ docker build -t python-app ./python-app
$ docker build -t java-app ./java-app
$ docker build -t apache-app ./Apache-app
$ docker build -t react-app ./React-app
$ docker build -t nginx-app ./nginx-app
```

## Run

```
$ docker run -d --name nodejs-app -p 3001:3000 nodejs-app
$ docker run -d --name python-app -p 3002:5000 python-app
$ docker run -d --name java-app -p 3003:8080 java-app
$ docker run -d --name apache-app -p 3004:80 apache-app
$ docker run -d --name react-app -p 3005:80 react-app
$ docker run -d --name nginx-app -p 3006:80 nginx-app
```

## Output

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

```
$ curl http://localhost:3001
<h1>Hello World from Node.js!</h1>

$ curl http://localhost:3002
<h1>Hello World from Python!</h1>

$ curl http://localhost:3003
<h1>Hello World from Java!</h1>

$ curl http://localhost:3004
<!DOCTYPE html>
<html>
<head><title>Apache</title></head>
<body>
  <h1>Hello World from Apache!</h1>
</body>
</html>

$ curl http://localhost:3006
<!DOCTYPE html>
<html>
<head><title>Nginx</title></head>
<body>
  <h1>Hello World from Nginx!</h1>
</body>
</html>
```

react app renders in the browser so i opened http://localhost:3005 in browser and it showed "Hello World from React!"
