## Headless Service

made by setting `clusterIP: None`. it does not give one virtual ip, instead dns returns the ip of **every pod** directly. this is what a StatefulSet needs so that each pod can be reached by its own name.

![Headless screenshot](Screenshot%202026-09-17%20235529.png)

CLUSTER-IP shows `None`. the statefulset pods came up as web-stateful-0, web-stateful-1, web-stateful-2 and nslookup of the service returned all 3 pod ips (10.244.0.83, .84, .85) instead of one service ip.

each pod can also be reached individually as `web-stateful-0.web-service-headless.default.svc.cluster.local`.
