## ClusterIP Service

default service type. it only gets a cluster internal ip, so it can be accessed only from inside the cluster. used for backend to backend communication.

tested it from the curl-client pod using the service name.

![ClusterIP screenshot](Screenshot%202026-09-17%20235308.png)

service got CLUSTER-IP 10.110.72.164 and no EXTERNAL-IP. `curl http://web-service-clusterip:8080` from inside the pod gave the nginx page, and the service load balances between the 3 pods.
