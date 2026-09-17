# Session 9 - Kubernetes Fundamentals HW

## Task 1: Run the docker compose app and check connectivity

ran the compose file from session8 (frontend nginx, backend nginx, database mysql)

```
docker compose up -d
docker compose ps
```

![Screenshot 1](Screenshot%202026-09-17%20232956.png)

then checked from inside the frontend container if backend and database are reachable. nginx image has no curl so i used bash /dev/tcp to test the port.

![Screenshot 2](Screenshot%202026-09-17%20233007.png)

**what i understood:** in this compose file i did not create any network, so compose put all 3 services in one default network (`session8-docker-networking-volume_default`). because of that frontend can reach both backend (port 80) and database (port 3306) by their service name. compose also gives dns, so `backend` and `database` resolve to their container ip.

if i want frontend to NOT reach the database then i have to make 2 networks and put database only in the backend network (like the demo compose file does).

also first time database gave "Connection refused" because mysql was still starting. after waiting ~30 sec it worked.

## Task 2 & 3: Install minikube and run the commands

installed kubectl and minikube in my ubuntu (wsl) and started the cluster with docker driver

```
minikube start
minikube status
```

![Screenshot 3](Screenshot%202026-09-17%20233051.png)

![Screenshot 4](Screenshot%202026-09-17%20233100.png)

minikube version v1.39.0, kubernetes v1.37.0, 1 node cluster. in `kubectl get pods -n kube-system` we can see the control plane components running as pods - etcd, kube-apiserver, kube-scheduler, kube-controller-manager, kube-proxy and coredns.

## Task 4: Kubernetes architecture and components

cluster has 2 parts - **control plane** (takes the decisions) and **worker nodes** (run the actual containers).

### Control plane

| component | what it does |
|---|---|
| kube-apiserver | the front door of the cluster. every request from kubectl or other components comes here. it authenticates, validates and then saves to etcd. only the apiserver talks to etcd |
| etcd | key-value database that stores the whole cluster state. if something is not in etcd, kubernetes doesn't know about it. needs backup in production |
| kube-scheduler | sees the new pods which have no node assigned and decides which node the pod should go to, based on cpu/memory, taints, affinity. it only decides, it does not start the container |
| kube-controller-manager | runs the control loops. it keeps comparing desired state with current state. if i asked for 3 replicas and only 2 are running, it creates 1 more |

### Worker node

| component | what it does |
|---|---|
| kubelet | agent on every node. it gets the pod spec from apiserver and tells the container runtime to start the containers. also reports pod health back |
| kube-proxy | makes the network rules (iptables / ipvs) on the node so that service traffic reaches the correct pods |
| container runtime | the software that actually pulls images and runs containers (containerd here, we can see `containerd 2.3.4` in the minikube start output) |

## Task 5: What happens in the background when i run `kubectl get pod`

1. kubectl reads `~/.kube/config` to get the cluster address and the certificates
2. it makes an https GET request to the **kube-apiserver** (`/api/v1/namespaces/default/pods`)
3. apiserver **authenticates** me (certificate) and then **authorizes** with RBAC (am i allowed to list pods in this namespace)
4. after that admission controllers are checked (for read requests not much happens here)
5. apiserver reads the pod list from **etcd**
6. apiserver sends the response back as json
7. kubectl formats that json into the table we see on screen

so kubectl never talks to etcd or to the nodes directly, everything goes through the api server.
