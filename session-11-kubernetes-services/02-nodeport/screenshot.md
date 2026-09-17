## NodePort Service

opens a fixed port (30000-32767) on the node, so the app can be accessed from outside the cluster using node-ip:nodeport.

![NodePort screenshot](Screenshot%202026-09-17%20235340.png)

service shows `80:30080/TCP`. i got the node ip with `minikube ip` (192.168.49.2) and then `curl http://192.168.49.2:30080` worked from outside the cluster.
