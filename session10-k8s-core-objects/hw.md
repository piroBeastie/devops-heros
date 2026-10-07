# Session 10 HW - Pods, ReplicaSets, Deployments & Deployment Strategies

**Name:** Nanakjot Singh Chahal
**Enrollment No:** 24bcs10132

minikube v1.39.0 (docker driver), kubernetes v1.37.0, single node cluster

---

## Task 1: Cluster health check

check client/server version, control plane + CoreDNS endpoints and node status before deploying anything.

```bash
kubectl version --output=yaml
kubectl cluster-info
kubectl get nodes -o wide
```

![Cluster health](screenshots/Screenshot%202026-09-18%20001101.png)

node is `Ready`, control plane and CoreDNS are both reachable.

---

## Task 2: Pod deploy, inspect and delete (`pod.yml`)

the 4 mandatory fields in every manifest are `apiVersion`, `kind`, `metadata`, `spec`. this pod has 2 containers (nginx + a busybox logger) so it shows **2/2**.

```bash
kubectl apply -f k8s-core-objects/pod.yml
kubectl get pods mypod
kubectl get pods mypod -o wide
kubectl logs mypod -c logger
kubectl delete -f k8s-core-objects/pod.yml
```

![Pod operations](screenshots/Screenshot%202026-09-18%20001153.png)

`-o wide` shows the pod IP (10.244.0.x) and the node it was placed on. the logger container keeps printing `log` every 5 seconds.

also applied it separately at the start:

![Pod apply](screenshots/Screenshot%202026-09-17%20233141.png)

---

## Task 3: ErrImagePull / ImagePullBackOff

used a pod with an image tag that does not exist.

```bash
kubectl apply -f pod-lifecycle/06-imagepullbackoff.yaml
kubectl get pods lifecycle-image-error
kubectl describe pod lifecycle-image-error | grep -A8 Events:
```

![ImagePullBackOff](screenshots/Screenshot%202026-09-18%20001225.png)

status goes `ErrImagePull` → `ImagePullBackOff` and the events show `Failed to pull image ... repository does not exist`.

**why the object is created but the container fails:** `kubectl apply` only sends the object to the api server, which validates it and saves it in **etcd** - that part succeeds because the yaml is valid. the image only gets pulled later, when the **kubelet** on the node tries to start the container. so the pod exists in the cluster but its container can never run, and kubelet keeps retrying with a longer and longer backoff (that is the "BackOff" part).

---

## Task 4: Transient pod lifecycle stages (`hello.yml`)

a busybox pod with `restartPolicy: Never` that just echoes and exits. i used `kubectl get pods -w` in one terminal and applied the file so i could catch every phase.

```bash
kubectl get pods -w | grep hello-pod      # terminal 1
kubectl apply -f hello.yml                # terminal 2
kubectl logs hello-pod
```

![Pod lifecycle stages](screenshots/Screenshot%202026-09-18%20001415.png)

caught all the phases: **Pending → ContainerCreating → Running (1/1) → Completed**. `kubectl logs` shows `Hello Kubernetes`.

with plain `kubectl get pods` every 2 seconds i could not catch `Running` at all because the echo command finishes in milliseconds - `-w` prints every state change so nothing is missed.

---

## Task 5: Pod lifecycle states & probes lab (`pod-lifecycle/`)

applied all 12 manifests at once first to see every state together:

```bash
kubectl apply -f pod-lifecycle/
kubectl get pods | grep lifecycle
```

![All lifecycle states](screenshots/Screenshot%202026-09-17%20233629.png)

| pod | status i got | why |
|---|---|---|
| lifecycle-running | Running | normal pod |
| lifecycle-pending | Pending | asks for 9Gi memory which the node does not have |
| lifecycle-succeeded | Completed | exit code 0 with `restartPolicy: Never` |
| lifecycle-failed | Error | exit code 1 with `restartPolicy: Never` |
| lifecycle-crashloop | Error / CrashLoopBackOff | keeps crashing, kubelet restarts with backoff |
| lifecycle-image-error | ErrImagePull | image does not exist |
| lifecycle-startup | 0/1 Running | running but startup probe not passed yet |
| lifecycle-multi-container | 2/2 Running | 2 containers in one pod |

### Pending + CrashLoopBackOff in detail

```bash
kubectl describe pod lifecycle-pending | grep -A4 Events:
kubectl logs lifecycle-crashloop --previous
```

![Pending and crashloop](screenshots/Screenshot%202026-09-18%20001511.png)

the pending pod's event is `FailedScheduling ... Insufficient memory` - the scheduler cannot find any node with 9Gi free. `--previous` shows the logs of the container instance that already died.

### Readiness, liveness and startup probes

```bash
kubectl apply -f 07-readiness.yaml -f 08-liveness.yaml -f 09-startup.yaml
for i in $(seq 1 6); do kubectl get pod lifecycle-readiness lifecycle-liveness lifecycle-startup --no-headers; sleep 12; done
```

![Probes](screenshots/Screenshot%202026-09-18%20002907.png)

- **liveness:** the container touches `/tmp/healthy`, sleeps 20s, then deletes it. the probe fails twice (failureThreshold=2, period=5s) and kubelet restarts the container - visible as `RESTARTS 1 (1s ago)` at 62s. this is kubernetes **self healing**.
- **startup:** shows `0/1 Running` for the first ~25 seconds, then becomes `1/1`. a startup probe protects slow starting apps so the liveness probe does not kill them while they are still booting.
- **readiness:** `Running` but a pod that is not Ready is removed from the service endpoints, so it gets no traffic. **Running != Ready**.

### Init container, sidecar and graceful termination

```bash
kubectl apply -f 10-init-container.yaml -f 11-multi-container.yaml -f 12-termination.yaml
kubectl logs lifecycle-multi-container -c sidecar
time kubectl delete pod lifecycle-termination
```

![Init, sidecar, termination](screenshots/Screenshot%202026-09-18%20001719.png)

- `lifecycle-multi-container` shows **2/2** and `-c sidecar` prints `Sidecar is running` - the app container and the logging sidecar share the pod.
- deleting the termination pod took **10.789 seconds** instead of being instant, because the container traps `SIGTERM` and does its cleanup inside `terminationGracePeriodSeconds`. that is a **graceful shutdown**.

---

## Task 6: ReplicaSet and StatefulSet

### ReplicaSet - self healing

```bash
kubectl apply -f k8s-core-objects/replicaset.yml
kubectl get rs
kubectl delete pod <one-pod>
kubectl get pods -l app=web
```

![ReplicaSet self healing](screenshots/Screenshot%202026-09-17%20233213.png)

i deleted one pod on purpose and the replicaset immediately created a new one, so the count went back to 3.

### StatefulSet - ordinal names and own storage

```bash
kubectl apply -f k8s-core-objects/statefulset.yml
kubectl get sts
kubectl get pods -l app=mysql
kubectl get pvc
```

![StatefulSet](screenshots/Screenshot%202026-09-17%20233428.png)

pods came up **in order** as `mysql-0`, `mysql-1`, `mysql-2` and each one got its own 5Gi PVC (`mysql-persistent-storage-mysql-0` etc), all Bound.

---

## Task 7: DaemonSet

```bash
kubectl apply -f k8s-core-objects/deamonset.yml
kubectl get ds
kubectl get pods -l app=node-exporter -o wide
```

![DaemonSet](screenshots/Screenshot%202026-09-17%20233303.png)

DESIRED = 1 and only 1 pod, because minikube has only 1 node. on a 3 node cluster it would automatically be 3 pods, one per node.

---

### Deployment → ReplicaSet → Pods

```bash
kubectl apply -f k8s-core-objects/deployment.yml
kubectl get deploy,rs,pods -l app=myapp
```

![Deployment hierarchy](screenshots/Screenshot%202026-09-17%20233235.png)

one command shows all three levels - the **deployment** created a **replicaset** (`myapp-xxxxx`) and that replicaset created the **3 pods**. i never made a replicaset myself, the deployment did it.

---

## Task 8: Rolling update and rollback (`01-rolling-update/`)

the file uses `maxSurge: 1` and `maxUnavailable: 0` which means: at most 1 extra pod above 3, and **zero** pods allowed to be unavailable → no downtime.

```bash
kubectl apply -f deployment-v1.yaml -f service.yaml
kubectl rollout status deployment/app-rolling
kubectl apply -f deployment-v2.yaml
kubectl rollout status deployment/app-rolling
```

![Rolling update](screenshots/Screenshot%202026-09-18%20001800.png)

```bash
kubectl get pods -l app=app-rolling
kubectl rollout history deployment/app-rolling
kubectl rollout undo deployment/app-rolling
```

![Rollout history and undo](screenshots/Screenshot%202026-09-18%20001830.png)

the rollout status output shows it going one pod at a time ("1 out of 3 new replicas have been updated", then 2, then 3) and old pods only terminate after new ones are up. `rollout undo` went back to the previous revision and the image changed back to nginx:1.24-alpine.

i also did the same thing with the `deployment/` folder files (v1 → v2), where old pods are `Terminating` while new ones are already `Running`:

![Deployment v1 to v2](screenshots/Screenshot%202026-09-17%20233526.png)

---

## Task 9: Troubleshooting drills (`troubleshooting/`)

### Drill 1 - broken-image.yaml (halted rollout)

```bash
kubectl apply -f troubleshooting/broken-image.yaml
kubectl get pods -l app=yatri-backend
kubectl rollout status deployment/yatri-backend --timeout=20s
```

![Broken image rollout](screenshots/Screenshot%202026-09-17%20233724.png)

the new surge pod goes **ImagePullBackOff** and `rollout status` times out - the rollout is stuck. but because of `maxUnavailable: 0` the 3 old pods stay **Running**, so the app never goes down.

```bash
kubectl describe pod <stuck-pod> | tail -8
kubectl rollout undo deployment/yatri-backend
```

![Describe and rollback](screenshots/Screenshot%202026-09-17%20233754.png)

describe shows `Failed to pull image "yatri-backend:non-existent-tag-v999" ... pull access denied, repository does not exist`. after `rollout undo` all 3 pods are Running again on the good image.

### Drill 2 - selector-mismatch.yaml (api server rejection)

the bug is one word: `spec.selector.matchLabels` says `app: correct-app-name` but the pod template label says `app: wrong-app-name`.

![Selector mismatch](screenshots/Screenshot%202026-09-17%20233810.png)

the api server rejects it straight away, no pod is even created:

```
The Deployment "selector-error-demo" is invalid: spec.template.metadata.labels:
Invalid value: {"app":"wrong-app-name"}: `selector` does not match template `labels`
```

**fix:** change `wrong-app-name` to `correct-app-name` in the template labels, then it is created. the selector is how the deployment finds its own pods, so if they don't match it could never manage them - and the selector is immutable after creation, which is why kubernetes blocks it up front.

---

## Task 10: Theory writeup

### The 4 ports

| port | where it lives | what it means |
|---|---|---|
| `containerPort` | pod spec | the port the app listens on **inside** the container. it is only documentation, it does not open anything |
| `targetPort` | service | the pod port the service sends traffic to (must match containerPort) |
| `port` | service | the port the **service itself** listens on inside the cluster (ClusterIP:port) |
| `nodePort` | service (NodePort/LoadBalancer) | a port 30000-32767 opened on **every node** so traffic can come from outside |

traffic path:

```
outside client ──► nodePort 30080 (node ip)
                      └──► port 80 (service cluster ip)
                             └──► targetPort 5000 (pod)
                                    └──► containerPort 5000 (app process)
```

### Labels vs Selectors

- **label** = a key-value tag put **on** an object, like `app: myapp` or `slot: blue`
- **selector** = a query that **looks for** those labels, used by services (to pick pods for endpoints) and by controllers (to know which pods belong to them)

labels are data, selectors are the filter. blue-green deployment works only because of this - i changed nothing but the service's selector, and the traffic moved.

### The 4 deployment strategies

| strategy | how it works | downtime | extra resources |
|---|---|---|---|
| **RollingUpdate** (default) | replaces old pods a few at a time, new pods start before old ones are removed | no | small (maxSurge) |
| **Recreate** | deletes all old pods first, then creates new ones | **yes** | none |
| **Blue-Green** | two full environments, service selector is flipped from blue to green in one shot | no | **2x** |
| **Canary** | small number of new pods next to the stable ones so only a small % of traffic sees the new version | no | small |

### maxSurge vs maxUnavailable

for `replicas: 4`, `maxSurge: 1`, `maxUnavailable: 0`:

- maximum pods during the rollout = `4 + 1 = 5`
- minimum available pods = `4 - 0 = 4` → full capacity the whole time, zero downtime

if they were percentages they are calculated on the replica count (`maxSurge: 25%` of 4 = 1, rounded **up**; `maxUnavailable: 25%` of 4 = 1, rounded **down**). `maxUnavailable: 0` means the rollout can get stuck instead of losing capacity - which is exactly what happened in the broken image drill.

### Requests vs Limits, and GB vs GiB

- **requests** = the guaranteed amount. the **scheduler** uses it to decide if a pod fits on a node. the pending pod in task 5 asked for 9Gi and never got scheduled.
- **limits** = the hard ceiling enforced by cgroups. over the **cpu** limit the container is throttled (slowed down); over the **memory** limit it is **OOM killed**.
- **units:** `1 GB = 10^9` bytes (decimal) but `1 Gi = 2^30 = 1073741824` bytes (binary). kubernetes uses the binary ones - `Mi` and `Gi`. so `1Gi` is about 7% more than `1G`. writing `512M` when you meant `512Mi` is a real bug.

---

## Task 11: Blue-Green deployment (`02-blue-green/`)

blue (v1, 3 pods) and green (v2, 3 pods) run **at the same time**, and the service picks one with the label `slot`.

```bash
kubectl apply -f deployment-blue.yaml -f deployment-green.yaml -f service-blue.yaml
kubectl get pods -l app=myapp --show-labels
kubectl describe svc myapp-service | grep Selector
curl http://$(minikube ip):30020
```

![Blue-green setup](screenshots/Screenshot%202026-09-18%20003132.png)

6 pods running (3 blue + 3 green), selector is `app=myapp,slot=blue` and the page says **BLUE ENVIRONMENT**.

### The cutover

```bash
kubectl get endpoints myapp-service
kubectl apply -f service-green.yaml
kubectl describe svc myapp-service | grep Selector
kubectl get endpoints myapp-service
curl http://$(minikube ip):30020
kubectl apply -f service-blue.yaml     # instant rollback
```

![Blue-green cutover](screenshots/Screenshot%202026-09-18%20003147.png)

the selector changed to `slot=green`, the **endpoints changed to 3 completely different pod IPs**, and the page immediately said **GREEN ENVIRONMENT**. applying service-blue.yaml again flipped it back to BLUE just as fast.

no pod was created or deleted for the switch - only the service selector changed. that is why blue-green rollback is instant, and also why it needs double the pods.

---

## Task 12: Canary deployment (`03-canary/`)

9 stable pods (v1) + 1 canary pod (v2), all with the same `app: myapp-canary` label so the single NodePort service spreads traffic over all 10.

```bash
kubectl apply -f deployment-stable.yaml -f deployment-canary.yaml -f service.yaml
kubectl get pods -l app=myapp-canary --show-labels
```

![Canary pods](screenshots/Screenshot%202026-09-17%20234842.png)

```bash
for i in $(seq 1 10); do curl -s http://$(minikube ip):30030 | grep -oE 'STABLE v1|CANARY v2'; done
```

![Canary traffic split](screenshots/Screenshot%202026-09-17%20234850.png)

10 requests gave **8 STABLE v1 and 2 CANARY v2** - roughly the 90/10 split. it is not exactly 9:1 every time because the service picks an endpoint randomly per connection.

### Shifting traffic and rolling back

```bash
kubectl scale deployment app-canary --replicas=3
kubectl scale deployment app-stable --replicas=7
kubectl scale deployment app-canary --replicas=0     # abort the canary
```

![Canary scaling](screenshots/Screenshot%202026-09-18%20003319.png)

after scaling to 3 canary / 7 stable the sample of 10 requests gave 5 canary and 5 stable - more than the 30% i expected, because 10 requests is a very small sample. after scaling canary to 0, all 6 requests went to **STABLE v1**, so the canary was rolled back with no downtime.

---

## Task 13: Recreate deployment and downtime (`04-recreate/`)

the file has `strategy: type: Recreate`.

```bash
kubectl apply -f deployment-v1.yaml -f service.yaml
kubectl get pods -l app=app-recreate
```

![Recreate v1](screenshots/Screenshot%202026-09-17%20234921.png)

then i ran a curl loop in one terminal and applied v2 in another:

```bash
while true; do curl -s --connect-timeout 1 http://$(minikube ip):30040 | grep -oE 'VERSION: [^<]*' || echo '[OUTAGE] connection refused / 0 pods alive'; sleep 1; done
kubectl apply -f deployment-v2.yaml
```

![Recreate downtime](screenshots/Screenshot%202026-09-18%20003222.png)

the loop shows exactly what recreate does:

```
VERSION: v1
VERSION: v1
[OUTAGE] connection refused / 0 pods alive     <-- all v1 pods gone, no v2 pod yet
VERSION: v2 (UPGRADED)
VERSION: v2 (UPGRADED)
```

watching the pods at the same time, all 3 old pods are **Terminating together** and only after that the new ones are created:

![Recreate pods](screenshots/Screenshot%202026-09-17%20235120.png)

the old replicaset hash was `6c78cb55bb` and the new one is `7bd8d89b8b`, and `rollout history` shows the new revision. this is the opposite of a rolling update, where some old pods keep serving while new ones start.
