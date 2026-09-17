# Session 9: Kubernetes Fundamentals & Cluster Architecture

**Name:** Nanakjot Singh Chahal
**Enrollment No:** 24bcs10132
**Session:** 09 - Kubernetes Fundamentals
**Repository:** devops-heros / session9-k8s

my setup: ubuntu 24.04 on wsl2, minikube v1.39.0 with docker driver, kubernetes v1.37.0

---

## Task 1: Minikube & CLI Installation Verification

check that minikube and kubectl are installed.

**Commands:**

```bash
minikube version
kubectl version --client
```

![Version check](screenshots/Screenshot%202026-09-18%20001048.png)

---

## Task 2: Starting the Minikube Kubernetes Cluster

start the single node cluster using the docker driver.

**Command:**

```bash
minikube start
```

![Minikube start](screenshots/Screenshot%202026-09-17%20233051.png)

in the output we can see it used the **docker driver**, pulled the base image, and prepared **kubernetes v1.37.0 on containerd 2.3.4**. at the end it says kubectl is now configured to use the "minikube" cluster.

---

## Task 3: Verifying Cluster Status & Node Health

check the control plane, kubelet, apiserver and that the node is Ready.

**Commands:**

```bash
minikube status
kubectl get nodes -o wide
kubectl cluster-info
```

![Minikube status and nodes](screenshots/Screenshot%202026-09-18%20001055.png)

node `minikube` is **Ready** with role control-plane, version v1.37.0, internal ip 192.168.49.2, os image Debian GNU/Linux 12 (bookworm) and container runtime `containerd://2.3.4`. `cluster-info` shows the control plane and CoreDNS endpoints on `https://127.0.0.1:32771`.

also checked the control plane components running as pods:

```bash
kubectl get pods -n kube-system
```

![kube-system pods](screenshots/Screenshot%202026-09-17%20233100.png)

here we can actually see etcd, kube-apiserver, kube-scheduler, kube-controller-manager, kube-proxy, coredns and storage-provisioner running as pods.

---

## Task 4: Stopping the Minikube Cluster

stop the cluster to free the system resources.

**Commands:**

```bash
minikube stop
minikube status
```

![Minikube stop](screenshots/Screenshot%202026-09-18%20005955.png)

after stop, status shows host, kubelet and apiserver all **Stopped**.

---

## Task 5: Kubernetes Cluster Architecture & Core Components

```
+-----------------------------------------------------------------+
|                     CONTROL PLANE (MASTER)                      |
|                                                                 |
|   +--------+      +----------------+      +----------------+    |
|   |  etcd  |<---->| kube-apiserver |<---->| kube-scheduler |    |
|   +--------+      +--------+-------+      +----------------+    |
|                            |                                    |
|                   +--------v----------------+                    |
|                   | kube-controller-manager |                    |
|                   +-------------------------+                    |
+----------------------------+------------------------------------+
                             |
              +--------------+--------------+
              v                             v
+---------------------------+  +---------------------------+
|       WORKER NODE 1       |  |       WORKER NODE 2       |
|  kubelet     kube-proxy   |  |  kubelet     kube-proxy   |
|        |         |        |  |        |         |        |
|   container runtime       |  |   container runtime       |
|     (containerd)          |  |     (containerd)          |
|        |                  |  |        |                  |
|   Pod 1     Pod 2         |  |   Pod 3     Pod 4         |
+---------------------------+  +---------------------------+
```

### Control plane components

| component | what it does |
|---|---|
| **kube-apiserver** | the front door of the cluster. every request (kubectl, dashboard, other components) comes here. it authenticates, authorizes with RBAC and validates before saving. it is the **only** component that talks to etcd |
| **etcd** | distributed key-value database that stores the whole cluster state, config and secrets. if it is not in etcd, kubernetes does not know about it. needs backup in production |
| **kube-scheduler** | watches for new pods that have no node assigned and decides which node they should run on, based on cpu/memory requests, taints, tolerations and affinity. it only **decides**, it does not start the container |
| **kube-controller-manager** | runs the control loops that compare **desired state** with **current state**. if i asked for 3 replicas and only 2 are running it creates one more. contains node controller, replicaset controller, endpoints controller etc |

### Worker node components

| component | what it does |
|---|---|
| **kubelet** | agent on every node. takes the PodSpec from the apiserver and tells the container runtime to start/stop containers. keeps checking container health and reports back |
| **kube-proxy** | maintains the network rules (iptables / ipvs) on the node so service traffic reaches the right pods |
| **container runtime (CRI)** | the software that actually pulls images and runs containers. my cluster uses **containerd 2.3.4** (docker shim is removed in new kubernetes versions) |
| **Pod** | smallest deployable unit. one or more containers sharing the same network namespace (same ip) and volumes |

### What happens in the background when i run `kubectl get pod`

1. kubectl reads `~/.kube/config` to get the cluster address and my certificate
2. it sends an HTTPS GET to the **kube-apiserver** (`/api/v1/namespaces/default/pods`)
3. apiserver **authenticates** me with the certificate, then **authorizes** with RBAC (am i allowed to list pods here)
4. admission controllers are checked (mostly for write requests)
5. apiserver reads the pod list from **etcd**
6. apiserver returns the data as json
7. kubectl formats that json into the table i see

so kubectl never talks to etcd or to the nodes directly. everything goes through the api server.

---

## Extra task: Docker Compose app and connectivity

also ran the compose app from session8 and checked if the frontend can reach the backend and the database.

```bash
docker compose up -d
docker compose ps
```

![Compose up](screenshots/Screenshot%202026-09-17%20232956.png)

then from inside the frontend container (nginx image has no curl, so i used bash `/dev/tcp` to test the ports):

![Compose connectivity](screenshots/Screenshot%202026-09-17%20233007.png)

**what i understood:** this compose file does not define any network, so compose puts all 3 services in one default network (`session8-docker-networking-volume_default`) and gives dns by service name. so frontend can reach **both** backend (port 80) and database (port 3306).

if i want the frontend to NOT reach the database, i have to make 2 networks and keep the database only in the backend network (that is what the `demo/docker-compose.yml` file does).

first try the database gave "Connection refused" because mysql was still starting up, after ~30 seconds it worked.

---

## Resources (from the course repo)

- https://kubernetes.io/docs/tutorials/kubernetes-basics/
- https://minikube.sigs.k8s.io/docs/start/
- https://kubernetes.io/docs/concepts/architecture/
- https://github.com/Nency-Ravaliya/Kubernetes
