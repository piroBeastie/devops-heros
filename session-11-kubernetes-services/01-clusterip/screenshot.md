## ClusterIP Service

default service type. it only gets a cluster internal ip, so it can be accessed only from inside the cluster. used for backend to backend communication.

tested it from the curl-client pod using the service name.

![ClusterIP screenshot](Screenshot%202026-09-17%20235308.png)

service got CLUSTER-IP 10.110.72.164 and no EXTERNAL-IP. `curl http://web-service-clusterip:8080` from inside the pod gave the nginx page, and the service load balances between the 3 pods.

### Endpoints and FQDN

![ClusterIP endpoints and FQDN](Screenshot%202026-09-18%20003551.png)

the endpoints object lists the 3 pod IPs behind the service. the short name `web-service-clusterip` and the full FQDN `web-service-clusterip.default.svc.cluster.local` both resolve to the same cluster ip.
