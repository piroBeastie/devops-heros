## ExternalName Service

this service does not have any pods or selector. it just makes a CNAME record in the cluster dns pointing to an outside domain, so pods can use one internal name instead of the real external address.

![ExternalName screenshot](Screenshot%202026-09-17%20235437.png)

`kubectl get svc` shows TYPE ExternalName, no CLUSTER-IP, and EXTERNAL-IP = nencyravaliya.me.

nslookup from the client pod returned `external-database-service.default.svc.cluster.local canonical name = nencyravaliya.me`, which proves it is a dns CNAME only - no proxying and no load balancing.
