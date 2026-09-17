# Session 12 HW - Differences and Deployment Strategies

## Task 1: StatefulSet vs Deployment vs DaemonSet

| | Deployment | StatefulSet | DaemonSet |
|---|---|---|---|
| used for | stateless apps (web, api) | stateful apps (databases) | node level agents |
| pod names | random hash - `myapp-7f98b-k2m9x` | fixed and in order - `mysql-0`, `mysql-1` | one per node with random suffix |
| order | no order, pods come up together | in order 0,1,2 and deleted in reverse | one pod on each node |
| how many pods | whatever replicas i set | whatever replicas i set | = number of nodes (automatic) |
| storage | usually shared or no storage | own PVC per pod from volumeClaimTemplates | mostly hostPath |
| service needed | normal service | headless service for pod dns | normal service / hostPort |
| example | nginx, rest api | mysql, kafka, mongodb | fluentd, node-exporter, kube-proxy |

## Task 2: ReplicaSet vs Deployment

| | ReplicaSet | Deployment |
|---|---|---|
| level | low level | high level, it manages replicasets |
| what it does | only keeps the given number of pods running | creates replicasets + gives updates, rollback, history |
| update image | have to delete pods manually to get the new image | rolling update automatically |
| rollback | not possible | `kubectl rollout undo` |
| history | no | `kubectl rollout history` |
| do we use it directly | no, rarely | yes, this is what we normally use |

deployment > replicaset > pods. when i applied a deployment i could see all three with `kubectl get deploy,rs,pods` (screenshot in hw1.md).

## Task 3: Deployment strategies

| strategy | what happens | downtime |
|---|---|---|
| Rolling update (default) | old pods are replaced few at a time, new pods come up before old ones go | no downtime |
| Recreate | all old pods are deleted first, then new pods are created | yes, small downtime |
| Blue-Green | 2 full environments (blue = old, green = new), service is switched from blue to green at once | no downtime but needs double resources |
| Canary | new version gets only a small part of the traffic (like 1 pod out of 10), if it is fine then scale it up | no downtime, safest for testing |

rolling update was already practiced in hw2.md. blue-green files are also in `02-blue-green`. below is the hands on for **canary** and **recreate**.

### Canary

9 pods of stable v1 + 1 pod of canary v2, both have the same label `app: myapp-canary` so the one NodePort service sends traffic to all 10 pods.

```
kubectl apply -f 03-canary/deployment-stable.yaml -f 03-canary/deployment-canary.yaml -f 03-canary/service.yaml
```

![Screenshot 1](screenshots/Screenshot%202026-09-17%20234842.png)

then i hit the service 10 times to see the traffic split

![Screenshot 2](screenshots/Screenshot%202026-09-17%20234850.png)

out of 10 requests i got **8 STABLE v1 and 2 CANARY v2**. it is not exactly 9:1 every time because the service picks a pod randomly, but on average it is around 10% traffic to the canary. this is how we test a new version on few users only.

### Recreate

the file has `strategy: type: Recreate`.

```
kubectl apply -f 04-recreate/deployment-v1.yaml -f 04-recreate/service.yaml
```

![Screenshot 3](screenshots/Screenshot%202026-09-17%20234921.png)

then updated to v2 and kept watching the pods every 3 seconds

![Screenshot 4](screenshots/Screenshot%202026-09-17%20235120.png)

in the first check all 3 old pods are **Terminating together** and there is no new pod yet - that is the downtime. after that the 3 new pods came up (age 3s). the old pod hash was `6c78cb55bb` and the new one is `7bd8d89b8b`, so it is a completely new replicaset.

this is the difference from rolling update - in rolling update some old pods keep serving while new ones start, in recreate everything goes down first.
