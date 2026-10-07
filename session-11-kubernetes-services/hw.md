# Session 11 HW - Kubernetes Networking & Services

**Name:** Nanakjot Singh Chahal
**Enrollment No:** 24bcs10132

the manifests are the ones in this folder.
each service type also has its own `screenshot.md` in its folder.

---

## Task 1: The 4 Kubernetes ports

```
Client Browser ──► [nodePort: 30080]   (node ip, opened on every node)
                        │
                        ▼
                   [port: 80]          (service cluster ip)
                        │
                        ▼
                   [targetPort: 80]    (pod network)
                        │
                        ▼
                   [containerPort: 80] (nginx process inside the container)
```

| port | scope | meaning |
|---|---|---|
| `containerPort` | pod | the port the app listens on inside the container. informational only, it does not open anything by itself |
| `targetPort` | service | which pod port the service forwards to (must match containerPort) |
| `port` | service | the port of the service itself (ClusterIP:port), used inside the cluster |
| `nodePort` | service | port 30000-32767 opened on every node, for traffic from outside |

```bash
kubectl explain service.spec.ports
kubectl get svc web-service-nodeport -o jsonpath='...'
```

![Ports](Screenshot%202026-09-18%20003546.png)

on my nodeport service: `port=80 targetPort=80 nodePort=30080`, and the deployment's `containerPort` is 80.

---

## Task 2: ClusterIP (default, internal only)

```bash
kubectl apply -f 01-clusterip/app-deployment.yaml -f 01-clusterip/service.yaml -f 01-clusterip/client-pod.yaml
kubectl get svc web-service-clusterip
kubectl exec curl-client -- curl -s http://web-service-clusterip:8080
```

![ClusterIP](01-clusterip/Screenshot%202026-09-17%20235308.png)

service got CLUSTER-IP `10.110.72.164` and **no external ip**, so it is reachable only from inside the cluster. curling the service name from the client pod returned the nginx page.

### Endpoints and FQDN

```bash
kubectl get svc,endpoints web-service-clusterip
kubectl exec curl-client -- curl -s http://web-service-clusterip.default.svc.cluster.local:8080
kubectl exec curl-client -- nslookup web-service-clusterip
```

![ClusterIP endpoints and FQDN](01-clusterip/Screenshot%202026-09-18%20003551.png)

the endpoints object lists the **3 pod IPs** behind the service - that is the list kube-proxy load balances over. the short name and the full FQDN both work.

---

## Task 3: NodePort (external access through the node)

```bash
kubectl apply -f 02-nodeport/app-deployment.yaml -f 02-nodeport/service.yaml
kubectl get svc web-service-nodeport
curl http://$(minikube ip):30080
```

![NodePort](02-nodeport/Screenshot%202026-09-17%20235340.png)

service shows `80:30080/TCP`. `minikube ip` gave `192.168.49.2` and curling `192.168.49.2:30080` from outside the cluster returned the nginx page.

---

## Task 4: LoadBalancer (needs a cloud provider, or minikube tunnel)

```bash
kubectl apply -f 03-loadbalancer/app-deployment.yaml -f 03-loadbalancer/service.yaml
kubectl get svc web-service-loadbalancer
```

![LoadBalancer pending](03-loadbalancer/Screenshot%202026-09-17%20235411.png)

at first EXTERNAL-IP is `<pending>` forever, because there is no cloud provider in minikube to create a real load balancer. a LoadBalancer service still allocates a NodePort (here `80:32687`) so i could test it that way.

### With minikube tunnel

```bash
sudo minikube tunnel        # in another terminal, keeps running
kubectl get svc web-service-loadbalancer
curl http://127.0.0.1
```

![LoadBalancer with tunnel](03-loadbalancer/Screenshot%202026-09-18%20003557.png)

with the tunnel running the EXTERNAL-IP became **127.0.0.1** and i could curl it on **plain port 80** - no high port number. the tunnel needs sudo because port 80 is a privileged port.

a LoadBalancer service is built on top of the other two: it creates a ClusterIP **and** a NodePort **and** then asks the cloud for an external ip.

---

## Task 5: ExternalName (DNS CNAME alias)

```bash
kubectl apply -f 04-externalname/service.yaml -f 04-externalname/client-pod.yaml
kubectl get svc external-database-service
kubectl exec dns-test-client -- nslookup external-database-service.default.svc.cluster.local
```

![ExternalName](04-externalname/Screenshot%202026-09-17%20235437.png)

TYPE is `ExternalName`, CLUSTER-IP is `<none>` and EXTERNAL-IP shows the domain. nslookup returned:

```
external-database-service.default.svc.cluster.local  canonical name = nencyravaliya.me
```

so it is **only a dns CNAME** - no pods, no selector, no endpoints, no proxying and no load balancing. it is used so the app can keep using an internal name like `db-service` while it actually points to an external managed database (RDS etc), and you only change the service if the external address changes.

---

## Task 6: Headless service (`clusterIP: None`)

```bash
kubectl apply -f 05-headless/app-statefulset.yaml -f 05-headless/service.yaml -f 05-headless/client-pod.yaml
kubectl get svc web-service-headless
kubectl exec headless-dns-client -- nslookup web-service-headless.default.svc.cluster.local
```

![Headless](05-headless/Screenshot%202026-09-17%20235529.png)

CLUSTER-IP is **None**, and nslookup of the service returned **3 separate A records** (the 3 pod IPs) instead of one virtual ip.

### Addressing one pod directly

```bash
kubectl exec headless-dns-client -- nslookup web-stateful-0.web-service-headless.default.svc.cluster.local
kubectl exec headless-dns-client -- curl -s http://web-stateful-0.web-service-headless:80
kubectl delete pod web-stateful-0
```

![Headless pod FQDN](05-headless/Screenshot%202026-09-18%20003625.png)

each pod has its own stable dns name `<pod>.<service>.<namespace>.svc.cluster.local`, and curling `web-stateful-0.web-service-headless` directly worked. after deleting `web-stateful-0` it came back with the **same name**. this is what a database cluster needs - each member has to be individually addressable, not load balanced.

---

## Task 7: Service without selector (manual endpoints)

a service with no selector does not get endpoints automatically - i created the `Endpoints` object myself, pointing at an ip outside the cluster.

![Service without selector](Screenshot%202026-09-18%20003807.png)

`kubectl get endpoints` first said **not found**, and after applying the Endpoints manifest it showed `192.168.1.150:3306`.

this is how you put a legacy/external server behind a normal kubernetes service name, so the apps inside the cluster can just use `external-legacy-db:3306` and not care that it is outside.

---

## Task 8: FQDN and CoreDNS

full writeup: [fqdn-coredns.md](fqdn-coredns.md)

```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl exec curl-client -- cat /etc/resolv.conf
kubectl exec curl-client -- nslookup web-service-clusterip.default.svc.cluster.local
```

![CoreDNS and FQDN](Screenshot%202026-09-17%20235536.png)

CoreDNS runs in `kube-system` and is exposed by the `kube-dns` service on `10.96.0.10`. every pod's `/etc/resolv.conf` has:

```
search default.svc.cluster.local svc.cluster.local cluster.local
nameserver 10.96.0.10
options ndots:5
```

FQDN format is `<service>.<namespace>.svc.cluster.local`.

**ndots:5 latency:** if the name i ask for has fewer than 5 dots, the resolver first tries it with every entry of the `search` list before trying it as a real domain. so `api.github.com` (2 dots) is first looked up as `api.github.com.default.svc.cluster.local`, then `...svc.cluster.local`, then `...cluster.local` - 3 failed queries before the correct one. for apps that call external APIs a lot this adds real latency, and the fix is to use a trailing dot (`api.github.com.`) or lower `ndots` in the pod's dnsConfig.

---

## Task 9: Pod identity - Deployment vs StatefulSet

deleted one pod from each and compared what came back.

```bash
kubectl delete pod web-app-clusterip-66865d4855-hjbjj
kubectl delete pod web-stateful-1
```

![Pod identity drill](Screenshot%202026-09-18%20003708.png)

| controller | deleted | came back as |
|---|---|---|
| Deployment | `web-app-clusterip-66865d4855-hjbjj` | `web-app-clusterip-66865d4855-ccc2g` → **new random name** |
| StatefulSet | `web-stateful-1` | `web-stateful-1` → **exactly the same name** |

deployment pods are interchangeable so the name does not matter. statefulset pods have an identity - the name, the dns record and the PVC all stay with the ordinal, so `web-stateful-1` always gets its own volume back.

---

## Task 10: Deployment vs StatefulSet vs DaemonSet

| | Deployment | StatefulSet | DaemonSet |
|---|---|---|---|
| **used for** | stateless apps, web, apis | stateful apps, databases | node level agents |
| **pod names** | random hash `web-7f98b-k2m9x` | ordinal `mysql-0,1,2` | node bound with random suffix |
| **identity** | throwaway, replaced by a new name | sticky - same name, dns and volume | tied to its node |
| **start/stop order** | no order, parallel | strictly `0 → 1 → 2`, deleted in reverse | one per node, in parallel |
| **how many pods** | whatever `replicas` says | whatever `replicas` says | = number of nodes, automatic |
| **storage** | shared volume or none | own PVC per pod from `volumeClaimTemplates` | usually `hostPath` |
| **service needed** | ClusterIP / NodePort / LoadBalancer | **headless** service (`clusterIP: None`) | usually none |
| **scaling** | anywhere there is room | adds/removes at the end only | automatic when nodes join/leave |
| **examples** | nginx, flask api, node.js | mysql, postgres, kafka, mongodb, zookeeper | fluentd, node-exporter, calico, kube-proxy |

---

## Task 11: Service selection and cloud cost

### Why 50 LoadBalancer services is a bad idea

```
BAD (one cloud load balancer per service, ~$25/month each):
  service A ──► LB 1 ($25)
  service B ──► LB 2 ($25)
  service C ──► LB 3 ($25)
  50 services = ~$1250 / month

GOOD (one load balancer + ingress):
  internet ──► 1 LB ($25) ──► NGINX Ingress Controller ──► ClusterIP A
                                  (host / path routing)  ──► ClusterIP B
                                                         ──► ClusterIP C
  50 services = ~$25 / month
```

on a cloud, `type: LoadBalancer` creates a **real** load balancer that is billed per hour, and each one also uses a public ip. so the normal production pattern is: keep all the apps as **ClusterIP** and put **one** ingress controller in front of them, exposed by a single LoadBalancer. that is also nicer because the ingress can do host based routing, path routing and TLS termination in one place.

### Decision tree

```
does it need to be reachable from outside the cluster?
│
├── NO ──► do clients need to reach individual pods (kafka, db cluster)?
│           ├── YES ──► HEADLESS SERVICE (clusterIP: None)
│           └── NO  ──► CLUSTERIP (default)
│
└── YES ─► is it actually an external service (RDS, an api)?
            ├── YES ──► EXTERNALNAME
            └── NO  ──► am i on a real cloud?
                         ├── YES + http/https ──► one INGRESS behind a LOADBALANCER,
                         │                        apps stay ClusterIP
                         ├── YES + raw tcp/udp ──► LOADBALANCER directly
                         └── NO (minikube/dev) ──► NODEPORT
```

---

## Task 12: Minikube docker driver port binding

```bash
minikube ip
curl http://192.168.49.2:30080
minikube service web-service-nodeport --url
```

![Minikube nodeport access](02-nodeport/Screenshot%202026-09-18%20003714.png)

on **my** setup the direct `node-ip:nodePort` worked and returned HTTP 200, because i run minikube with the docker driver inside **linux (wsl2 ubuntu)**, so the docker bridge network `192.168.49.0/24` is reachable from the same linux kernel.

on **macOS or Windows** the same command fails/times out. there the docker daemon runs inside its own VM, so `192.168.49.2` only exists inside that VM and the host kernel has no route to it. the 2 workarounds are:

- `minikube service <svc> --url` - opens a temporary proxy on `127.0.0.1:<random-port>` and prints the url to use
- `minikube tunnel` - keeps running and adds host routes so node ips and LoadBalancer external ips become reachable (needs sudo). this is the one i used in Task 4 to get an EXTERNAL-IP.
