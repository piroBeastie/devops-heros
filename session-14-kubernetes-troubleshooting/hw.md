# Session 14 HW - Kubernetes Troubleshooting

**Name:** Nanakjot Singh Chahal
**Enrollment No:** 24bcs10132

ran all the labs and the failure scenarios from this folder on minikube.

---

## logs vs events (the main difference)

| | `kubectl logs` | `kubectl get events` / `describe` |
|---|---|---|
| comes from | the **application** inside the container (stdout/stderr) | the **kubernetes control plane** (scheduler, kubelet) |
| tells you | what the app printed, app crashes, tracebacks | scheduling failures, image pulls, restarts, evictions |
| use when | the pod is Running but the app misbehaves | the pod is **not** Running (Pending, ImagePullBackOff, CrashLoop) |
| kept for | as long as the pod exists | about 1 hour (events expire) |

short version: **events tell you why the pod is not running, logs tell you why the app is not working.**

---

## 1. kubectl get

```bash
kubectl apply -f 01-kubectl-get/pod.yaml
kubectl get pod get-demo
kubectl get pod get-demo -o wide
kubectl get pod get-demo -o jsonpath='{.status.phase} {.status.podIP} {.spec.nodeName}'
kubectl get all
```

![kubectl get](screenshots/Screenshot%202026-10-07%20164810.png)

`get` is the quick look - READY, STATUS, RESTARTS, AGE. `-o wide` adds the pod IP and the node. `-o jsonpath` pulls out single fields, which is what you use in scripts.

---

## 2. kubectl describe

```bash
kubectl apply -f 02-kubectl-describe/demo-pod.yaml
kubectl describe pod describe-demo
```

![kubectl describe](screenshots/Screenshot%202026-10-07%20164836.png)

describe gives the full picture of one object - labels, node, IP, container image, state, volumes, and most importantly the **Events** at the bottom (Scheduled → Pulled → Created → Started). this is the first command to run when a pod is not starting.

---

## 3. kubectl logs

```bash
kubectl apply -f 03-kubectl-logs/pod.yaml
kubectl logs logs-demo
kubectl logs logs-demo --tail=3
kubectl logs logs-demo --timestamps
```

![kubectl logs](screenshots/Screenshot%202026-10-07%20164907.png)

this pod is a busybox that keeps printing log lines. `--tail=N` shows only the last N lines and `--timestamps` adds the time to each line. other useful ones: `-f` to follow live, `--previous` for the crashed container, and `-c <container>` when the pod has more than one container.

---

## 4. kubectl exec

```bash
kubectl apply -f 04-kubectl-exec/pod.yaml
kubectl exec exec-demo -- hostname
kubectl exec exec-demo -- nginx -v
kubectl exec exec-demo -- sh -c 'ls /usr/share/nginx/html; cat /etc/os-release'
kubectl exec exec-demo -- env
```

![kubectl exec](screenshots/Screenshot%202026-10-07%20164934.png)

exec runs a command **inside** the running container. useful for checking config files, env variables, dns and whether the app is really listening. `kubectl exec -it <pod> -- sh` gives an interactive shell.

---

## 5. kubectl events

```bash
kubectl apply -f 05-events/pod.yaml
kubectl get events --field-selector involvedObject.name=events-demo
kubectl get events --sort-by=.lastTimestamp
```

![kubectl events](screenshots/Screenshot%202026-10-07%20165000.png)

the events show the pod lifecycle in order: **Scheduled → Pulled → Created → Started**. `--field-selector` filters to one object, `--sort-by=.lastTimestamp` puts the newest at the bottom (by default events are not in time order, which is confusing).

---

## 6. CrashLoopBackOff

the container runs a command that exits with code 1 on purpose.

```bash
kubectl apply -f 06-crashloopbackoff/broken-pod.yaml
kubectl get pod crash-demo
kubectl logs crash-demo --tail=4
kubectl describe pod crash-demo | grep -E 'Last State|Exit Code|Reason|Restart Count'
```

![CrashLoopBackOff](screenshots/Screenshot%202026-10-07%20165604.png)

the pod shows `Error` / `CrashLoopBackOff` with **RESTARTS going up**. describe shows `Last State: Terminated`, `Reason: Error`, `Exit Code: 1`.

"BackOff" means kubelet waits longer and longer between restarts (10s, 20s, 40s... up to 5 min) so a broken container does not hammer the node.

### the fix

```bash
diff broken-pod.yaml fixed-pod.yaml
kubectl apply -f 06-crashloopbackoff/fixed-pod.yaml
```

![CrashLoop fixed](screenshots/Screenshot%202026-10-07%20165148.png)

the diff shows the broken one does `exit 1` while the fixed one keeps running with a `sleep` loop. after applying the fixed pod it stays `1/1 Running` with 0 restarts.

---

## 7. ImagePullBackOff

```bash
kubectl apply -f 07-imagepullbackoff/broken-pod.yaml
kubectl get pod image-demo
kubectl describe pod image-demo | grep -A5 Events:
kubectl apply -f 07-imagepullbackoff/fixed-pod.yaml
```

![ImagePullBackOff](screenshots/Screenshot%202026-10-07%20165251.png)

the image is `nginx:this-image-does-not-exist`. the pod goes `ErrImagePull` → `ImagePullBackOff` and the event says the manifest was not found.

important difference from CrashLoopBackOff: here the container **never started at all**, so `kubectl logs` gives nothing useful - you have to use `describe`/events. the fix is just the correct tag (`nginx:1.27`) and then it runs.

---

## 8. Pending pod

```bash
grep -A2 nodeSelector 08-pending-pods/broken-pod.yaml
kubectl apply -f 08-pending-pods/broken-pod.yaml
kubectl get pod pending-demo
kubectl describe pod pending-demo | grep -A3 Events:
```

![Pending pod](screenshots/Screenshot%202026-10-07%20165343.png)

the pod asks for `nodeSelector: kubernetes.io/hostname: node-that-does-not-exist`, so it stays **Pending** forever and the event is:

```
Warning  FailedScheduling  0/1 nodes are available: 1 node(s) didn't match Pod's node affinity/selector.
```

Pending always means the **scheduler** could not place the pod. usual reasons: not enough cpu/memory on any node, a nodeSelector/affinity that matches nothing, taints without a toleration, or an unbound PVC. removing the nodeSelector (the fixed file) makes it Running immediately.

---

## 9. Service / DNS troubleshooting

```bash
kubectl apply -f 09-service-dns-troubleshooting/deployment.yaml -f 09-service-dns-troubleshooting/broken-service.yaml
kubectl get endpoints broken-service
kubectl exec dns-test -- nslookup broken-service.default.svc.cluster.local
```

![Broken service](screenshots/Screenshot%202026-10-07%20165651.png)

the pods are Running and the dns name **does** resolve (the service has a ClusterIP), but `kubectl get endpoints` shows `<none>` - so traffic goes nowhere. the reason is the service selector says `app: does-not-exist` while the pods are labelled `app: web`.

**this is the single most common service bug:** dns works, the service exists, but endpoints are empty because the selector does not match the pod labels.

### fixing it

![Service fixed](screenshots/Screenshot%202026-10-07%20165959.png)

i noticed the provided `service.yaml` is **also wrong** - its selector is `app: web-ahsgdf`, so applying it still left `ENDPOINTS <none>`. i fixed it with:

```bash
sed 's/app: web-ahsgdf/app: web/' service.yaml > /tmp/web-service-fixed.yaml
kubectl apply -f /tmp/web-service-fixed.yaml
```

after that the endpoints filled in with the 2 real pod IPs (`10.244.0.30:80,10.244.0.32:80`) and a test pod got the nginx page:

```
kubectl run tmp-test --image=curlimages/curl:8.5.0 --restart=Never --rm -i -- curl -s http://web-service
<title>Welcome to nginx!</title>
```

**debug order for a service:** pods Running? → labels match the selector? → `get endpoints` not empty? → dns resolves? → port/targetPort correct?

---

## 10. Scenario - OOMKilled

```bash
kubectl apply -f scenarios/scenario-5-oomkilled/broken.yaml
kubectl get pod fail-5-oomkilled-pod
kubectl describe pod fail-5-oomkilled-pod | grep -E 'Reason|Exit Code|Last State'
```

![OOMKilled](screenshots/Screenshot%202026-10-07%20165810.png)

a python container that keeps allocating memory with a limit of only `20Mi`. the status is literally **OOMKilled** with **Exit Code 137**.

137 = 128 + 9, meaning the process was killed by signal 9 (SIGKILL) - the kernel's OOM killer did it because the container went over its memory **limit**. the fix is either raising the limit or fixing the app's memory use. this one is not a code bug you can see in the logs, which is why the status/exit code matters.

---

## 11. Mini project

```bash
kubectl apply -f mini-project/deployment.yaml -f mini-project/service.yaml -f mini-project/broken-pod.yaml
kubectl get pods -l app=troubleshooting-app
kubectl get pod project-broken-pod
kubectl describe pod project-broken-pod | grep -A3 Events:
kubectl get endpoints web-service
```

![Mini project](screenshots/Screenshot%202026-10-07%20165858.png)

the deployment's 2 pods come up fine, and `project-broken-pod` (image `nginx:this-tag-does-not-exist`) goes to ImagePullBackOff - so a broken pod sitting next to a healthy deployment does not affect it.

---

## Troubleshooting cheat sheet i ended up with

| status | what it means | first command |
|---|---|---|
| `Pending` | scheduler could not place it | `kubectl describe pod` → Events |
| `ImagePullBackOff` / `ErrImagePull` | image name/tag wrong or registry needs auth | `kubectl describe pod` |
| `CrashLoopBackOff` | container starts then exits | `kubectl logs` (+ `--previous`) |
| `OOMKilled` (exit 137) | hit the memory limit | `kubectl describe` + raise limit |
| `Running` but app broken | app level problem | `kubectl logs`, `kubectl exec` |
| `Running` but unreachable | service selector / endpoints | `kubectl get endpoints` |
| `0/1 Running` | readiness probe not passing | `kubectl describe pod` |
