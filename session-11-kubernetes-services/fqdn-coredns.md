# FQDN and CoreDNS in Kubernetes

## Why we need dns here

pod ips keep changing - every time a pod restarts or is rescheduled it gets a new ip. so we can never hardcode a pod ip in our app. instead we use the **service name**, and kubernetes dns converts that name to the current ip. this is how one microservice finds another.

## CoreDNS

CoreDNS is the dns server of the cluster. it runs as a normal deployment in the `kube-system` namespace and is exposed by a service called `kube-dns`.

- every service and pod gets a dns record in CoreDNS
- CoreDNS watches the api server, so when a new service is created its record is added automatically
- if the name is not a cluster name (like google.com) CoreDNS forwards it to the upstream dns of the node

![CoreDNS and FQDN](Screenshot%202026-09-17%20235536.png)

from my cluster:

```
$ kubectl get pods -n kube-system -l k8s-app=kube-dns
coredns-559f6c778d-tqdbz   1/1   Running

$ kubectl get svc -n kube-system kube-dns
kube-dns   ClusterIP   10.96.0.10   53/UDP,53/TCP,9153/TCP
```

kubelet puts this `10.96.0.10` as the nameserver inside every pod's `/etc/resolv.conf`:

```
search default.svc.cluster.local svc.cluster.local cluster.local
nameserver 10.96.0.10
options ndots:5
```

## FQDN (Fully Qualified Domain Name)

FQDN is the full dns name of a service. format:

```
<service-name>.<namespace>.svc.<cluster-domain>
```

example from my cluster:

```
web-service-clusterip.default.svc.cluster.local
```

- `web-service-clusterip` - name of the service
- `default` - namespace it is in
- `svc` - means it is a service
- `cluster.local` - default cluster domain

nslookup of this FQDN returned `10.110.72.164` which is the ClusterIP of that service.

### For pods of a StatefulSet (headless service)

```
<pod-name>.<service-name>.<namespace>.svc.cluster.local
```

like `web-stateful-0.web-service-headless.default.svc.cluster.local`.

## Short names and the search list

because of the `search` line in resolv.conf we don't have to type the full FQDN:

| what i write | when it works |
|---|---|
| `web-service-clusterip` | only if my pod is in the same namespace |
| `web-service-clusterip.default` | from any namespace |
| `web-service-clusterip.default.svc.cluster.local` | always (this is the FQDN) |

**ndots:5** means if the name i typed has less than 5 dots, the resolver first tries it with each entry of the search list before trying it as it is. that is why a short name works inside the cluster. it also means external names like `google.com` (1 dot) go through a few failed lookups first, so using the full FQDN (with a dot at the end) is faster for external domains.
