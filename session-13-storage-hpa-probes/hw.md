# Session 13 HW - Storage, HPA & Probes

**Name:** Nanakjot Singh Chahal
**Enrollment No:** 24bcs10132

ran all the labs from this folder on my minikube cluster (kubernetes v1.37.0, docker driver on wsl2).

---

## 1. Volumes - emptyDir

`emptyDir` gives the pod an empty directory when it starts. all containers in that pod can use it, but it lives and dies **with the pod**.

```bash
kubectl apply -f 01-volumes/emptydir-pod.yaml
kubectl exec emptydir-demo -- sh -c 'echo hello-from-emptydir > /data/test.txt; cat /data/test.txt'
```

![emptyDir pod](screenshots/Screenshot%202026-10-07%20163441.png)

### what happens when the pod is deleted

```bash
kubectl delete pod emptydir-demo
kubectl apply -f 01-volumes/emptydir-pod.yaml
kubectl exec emptydir-demo -- ls -la /data
```

![emptyDir after delete](screenshots/Screenshot%202026-10-07%20163509.png)

`/data` is **empty** - `total 8` with only `.` and `..`. the file i wrote is gone. so emptyDir survives a container restart inside the pod, but not pod deletion. it is for scratch/cache data only.

---

## 2. Volumes - hostPath

`hostPath` mounts a real directory **from the node** into the pod, so the data stays on the node even after the pod is gone.

```bash
kubectl apply -f 01-volumes/hostpath-pod.yaml
kubectl exec hostpath-demo -- sh -c 'echo written-from-pod > /data/node-file.txt'
minikube ssh -- 'cat /tmp/hostpath-data/node-file.txt'
```

![hostPath pod](screenshots/Screenshot%202026-10-07%20163535.png)

i wrote the file inside the pod at `/data`, then logged into the node with `minikube ssh` and the same file was there at `/tmp/hostpath-data/` - proving the volume really is the node's directory.

hostPath is risky in real clusters: if the pod gets scheduled on a different node, the data is not there, and it gives the pod access to the node filesystem.

---

## 3. Persistent Storage - PV and PVC

- **PV (PersistentVolume)** = the actual storage piece in the cluster
- **PVC (PersistentVolumeClaim)** = the pod's request for storage ("i need 500Mi")

the pod only talks about the **claim**, never the volume, so storage is decoupled from the pod.

```bash
kubectl apply -f 02-persistent-storage/pv.yaml -f 02-persistent-storage/pvc.yaml
kubectl get pv
kubectl get pvc
kubectl apply -f 02-persistent-storage/pod.yaml
```

![PV and PVC](screenshots/Screenshot%202026-10-07%20163612.png)

### the data survives the pod

```bash
kubectl exec storage-demo -- sh -c 'echo "Kubernetes Storage" > /data/message.txt'
kubectl delete pod storage-demo
kubectl apply -f 02-persistent-storage/pod.yaml
kubectl exec storage-demo -- cat /data/message.txt
```

![PVC data survives](screenshots/Screenshot%202026-10-07%20163639.png)

the new pod read back **`Kubernetes Storage`**. this is the whole difference from emptyDir - the data is in the volume, not in the pod.

### one thing i noticed

`kubectl get pv` showed **two** volumes:

```
pvc-4883f9c3-...   500Mi   Delete   Bound       default/student-pvc   standard
student-pv         1Gi     Retain   Available
```

the `student-pv` i created by hand stayed **Available** and was never used. the PVC got a brand new **dynamically provisioned** 500Mi volume instead, because the PVC does not name a specific volume and the cluster has a default StorageClass (`standard`), so the provisioner made one automatically. the manual PV was also 1Gi/Retain while the claim asked for 500Mi.

to actually bind to my own PV i would have to remove the storageClassName (set it to `""`) in the PVC or use a matching selector.

---

## 4. StorageClass (dynamic provisioning)

a StorageClass is the "type of storage" and which provisioner creates it. with one, i do not have to create PVs by hand at all.

```bash
kubectl get storageclass
kubectl describe storageclass standard
kubectl apply -f 03-storageclass/pvc.yaml
kubectl get pvc dynamic-pvc
kubectl get pv
```

![StorageClass](screenshots/Screenshot%202026-10-07%20163657.png)

minikube has one class `standard (default)` with provisioner `k8s.io/minikube-hostpath`, ReclaimPolicy `Delete` and VolumeBindingMode `Immediate`.

as soon as i applied the PVC it became **Bound** to a volume `pvc-7897c69e-...` that i never created - the provisioner made it on demand. `IsDefaultClass: Yes` is why a PVC with no storageClassName still works.

`Delete` reclaim policy means when the PVC is deleted the volume is deleted too (good for dev, dangerous for databases - there `Retain` is used).

---

## 5. Probes

| probe | question it answers | what happens on failure |
|---|---|---|
| **liveness** | is the app still alive? | kubelet **restarts** the container |
| **readiness** | can it take traffic right now? | pod is removed from the **service endpoints** (not restarted) |
| **startup** | has it finished booting? | liveness/readiness are held back until it passes |

```bash
kubectl apply -f 05-probes/liveness.yaml -f 05-probes/readiness.yaml -f 05-probes/startup.yaml
kubectl get pods liveness-demo readiness-demo startup-demo
kubectl describe pod liveness-demo | grep -A1 'Liveness:'
```

![Probes](screenshots/Screenshot%202026-10-07%20163826.png)

all 3 pods are `1/1 Running` and describe shows the actual probe settings:

- liveness: `http-get http://:80/ delay=5s timeout=2s period=5s failureThreshold=3`
- readiness: `http-get http://:80/ delay=5s period=5s failureThreshold=3`
- startup: `http-get http://:80/ delay=0s period=2s failureThreshold=30` → gives the app up to 60s to boot

the startup probe with `failureThreshold: 30` and `period: 2s` is the pattern for slow legacy apps - without it, a liveness probe would keep killing the container before it ever finished starting.

---

## 6. HPA (Horizontal Pod Autoscaler)

HPA watches a metric (cpu here) and changes the **number of replicas** automatically. it needs **metrics-server** to read pod cpu.

```bash
minikube addons enable metrics-server
kubectl apply -f 04-hpa/deployment.yaml -f 04-hpa/service.yaml
kubectl apply -f 04-hpa/hpa.yaml
kubectl get hpa hpa-demo
kubectl top pods -l app=hpa-demo
```

![HPA setup](screenshots/Screenshot%202026-10-07%20163919.png)

the deployment asks for `cpu: 100m` (request) with a `200m` limit, and the HPA targets **50% average cpu**, min 1 pod, max 5. so 50% of 100m = 50m is the line where it starts scaling.

### load test - watching it scale

```bash
kubectl run load-generator --image=busybox:1.36 --restart=Never -- /bin/sh -c 'while true; do wget -q -O- http://hpa-demo-service; done'
for i in $(seq 1 9); do kubectl get hpa hpa-demo --no-headers; sleep 20; done
```

![HPA scaling up](screenshots/Screenshot%202026-10-07%20164227.png)

this is the actual autoscaling happening:

```
cpu: <unknown>/50%   1   5   1    52s     <- metrics not collected yet
cpu: 62%/50%         1   5   1   112s     <- load arrives, above target
cpu: 62%/50%         1   5   2   2m12s    <- HPA scaled 1 -> 2 replicas
cpu: 42%/50%         1   5   2   2m53s    <- now 42% because load is split over 2 pods
```

first the metric shows `<unknown>` for about 90 seconds because metrics-server had not scraped yet. then cpu went to **62%**, over the 50% target, and the HPA added a second replica. after that the average dropped to **42%** - below target - so it stopped scaling. exactly how it is supposed to work.

![HPA after load](screenshots/Screenshot%202026-10-07%20164315.png)

after deleting the load generator it stays at 2 replicas for a while - HPA has a **5 minute stabilization window** for scaling *down*, so it does not flap up and down on short spikes.

---

## 7. Mini project - namespace + PVC + deployment + service + HPA

the mini-project puts everything together in its own namespace.

```bash
kubectl apply -f mini-project/namespace.yaml -f mini-project/pvc.yaml \
  -f mini-project/deployment.yaml -f mini-project/service.yaml -f mini-project/hpa.yaml
kubectl get pvc,hpa -n production-webapp
kubectl get pods -n production-webapp
```

![Mini project](screenshots/Screenshot%202026-10-07%20164430.png)

### persistence test

```bash
kubectl exec -n production-webapp <pod> -- sh -c 'echo "Student: Nanakjot Singh Chahal" > /data/student.txt'
kubectl delete pod -n production-webapp <pod>
kubectl exec -n production-webapp <new-pod> -- cat /data/student.txt
```

![Mini project persistence](screenshots/Screenshot%202026-10-07%20164507.png)

i wrote my name into the PVC from pod `web-app-d45775485-6nzd8`, deleted that pod, and the replacement pod `web-app-d45775485-v5kqq` could still read `Student: Nanakjot Singh Chahal`.

so the deployment keeps the replica count, the HPA can scale it, and the PVC keeps the data no matter which pod is running - that is the point of the whole session.

---

## Summary

| thing | use it for | data lifetime |
|---|---|---|
| `emptyDir` | scratch space, cache, sharing files between containers in one pod | dies with the pod |
| `hostPath` | node level files (logs, docker socket) | stays on that one node |
| PV + PVC | real app data | independent of the pod |
| StorageClass | automatic PV creation | per reclaim policy (`Delete`/`Retain`) |
| liveness probe | restart a hung container | - |
| readiness probe | keep traffic away until ready | - |
| startup probe | protect slow starting apps | - |
| HPA | handle changing load automatically | - |
