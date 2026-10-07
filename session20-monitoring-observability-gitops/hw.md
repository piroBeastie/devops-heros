# Session 20 HW - Monitoring, Observability & GitOps

**Name:** Nanakjot Singh Chahal
**Enrollment No:** 24bcs10132

> the labs say `kind create cluster --name session20`. i already have a minikube cluster that i have been using since session 9, so i ran everything on that instead of installing kind. every other command is exactly as written.

---

## 1. Monitoring vs Observability

| monitoring | observability |
|---|---|
| is something wrong? | **why** is it wrong? |
| known failure signals | explore problems nobody predicted |
| dashboards and alerts | metrics + logs + traces together |

monitoring is the dashboard light. observability is being able to open the bonnet.

the way i think about it: monitoring tells me latency is 2 seconds. observability is what lets me find out that 1.2s of those 2 seconds were spent in the database. you need both - monitoring to know you have a problem at 3am, observability to fix it.

---

## 2. Metrics, Logs & Traces

| signal | answers | example |
|---|---|---|
| **metrics** | how much / how often | `http_requests_total 1200` |
| **logs** | what happened | `ERROR Database timeout` |
| **traces** | where the time went | api 20ms -> order 80ms -> db 600ms |

### the kubernetes demo

```bash
kubectl apply -f k8s-demo/
kubectl get pods -l app=session20-demo
kubectl logs deployment/session20-demo --tail=6
```

![metrics logs traces demo](screenshots/Screenshot%202026-10-07%20175652.png)

the pod is a busybox loop that prints a line every 10 seconds, and `kubectl logs` shows exactly what the README said it would:

```
Session 20 observability demo started
Request received
Health check OK
```

that is the **logs** signal - discrete events with no numbers attached.

```bash
kubectl describe deployment session20-demo | head -28
```

![describe deployment](screenshots/Screenshot%202026-10-07%20175657.png)

`describe` is where you get the shape of the workload: selector `app=session20-demo`, `1 desired | 1 updated | 1 total | 1 available | 0 unavailable`, RollingUpdate with 25% max unavailable / 25% max surge, and the full container command.

this little demo has no `/metrics` endpoint, which is the honest limitation - it produces logs only. to get the metrics signal out of a real app you expose a prometheus endpoint, which is what the next section is about.

---

## 3. Prometheus

```bash
cat prometheus.yml
docker compose up -d
docker compose ps
```

![prometheus up](screenshots/Screenshot%202026-10-07%20174901.png)

the config is 6 lines - a 5 second scrape interval and one target, prometheus scraping itself:

```yaml
global:
  scrape_interval: 5s
scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets:
          - prometheus:9090
```

`prometheus:9090` works because compose puts the container on a network where the **service name** is a DNS name. same trick as the docker networking session.

### querying it

```bash
curl -s 'http://localhost:9090/api/v1/query?query=up' | python3 -m json.tool
curl -s 'http://localhost:9090/api/v1/targets' | python3 -m json.tool | grep -E 'scrapeUrl|health|job'
curl -s http://localhost:9090/metrics | grep '^prometheus_http_requests_total'
```

![prometheus api](screenshots/Screenshot%202026-10-07%20174926.png)

```
"metric": { "__name__": "up", "instance": "prometheus:9090", "job": "prometheus" },
"value": [ 1791375564.485, "1" ]
```

so `up = 1`, and the target health is `up` with the scrape url `http://prometheus:9090/metrics`.

one thing i hit: the **first** time i ran this right after `compose up`, `result` came back as an empty list `[]` and the target health was `"unknown"`. nothing was broken - prometheus simply had not scraped yet. a metric does not exist until a scrape produces it.

### in the browser

`http://localhost:9090` and query `up`:

![prometheus ui query](screenshots/Screenshot%202026-10-07%20175512.png)

```
up{instance="prometheus:9090", job="prometheus"}    1
```

Status > Target health:

![prometheus targets](screenshots/Screenshot%202026-10-07%20175524.png)

`prometheus  1/1 up`, last scrape 703ms ago, scrape duration 4ms. this page is the first place to look when a dashboard goes blank - if the target is DOWN, nothing downstream can work.

### the practice questions

1. **what does prometheus collect?** metrics - numeric time series.
2. **what is a scrape?** prometheus doing an HTTP GET on a target's `/metrics` endpoint and storing the numbers it finds. it is a **pull** model; the app does not push anything.
3. **what does `up` mean?** a metric prometheus generates itself for every target: 1 = the last scrape succeeded, 0 = it failed.
4. **what is PromQL?** the query language. `up` is a query, `sum(up)` aggregates it.
5. **metrics or logs?** metrics. prometheus is not log storage - that is loki's job.

---

## 4. Grafana

```bash
docker compose up -d
docker compose ps
```

![grafana compose](screenshots/Screenshot%202026-10-07%20180833.png)

both containers from one compose file - `session20-prometheus` on 9090 and `session20-grafana` on 3000.

### adding the data source

logged in at `http://localhost:3000` with admin/admin (it asks you to change the password - i skipped it, this is a throwaway lab container). then Connections > Data sources > Add data source > Prometheus, with the url:

```
http://prometheus:9090
```

and Save & test:

![data source saved](screenshots/Screenshot%202026-10-07%20175547.png)

> **Successfully queried the Prometheus API.**

the url is the thing to get right. `http://localhost:9090` does **not** work here, even though that is the address i use in my own browser - because the request is made by the grafana *container*, and inside that container localhost is grafana itself. it has to be the compose service name.

### the dashboard

new dashboard > add visualization > prometheus > query `up` > visualization type **Stat**:

![grafana dashboard](screenshots/Screenshot%202026-10-07%20175559.png)

a big green **1**, meaning the target is up. i saved it as "Session 20 Monitoring".

so the split is: prometheus scrapes and stores, grafana only asks prometheus questions and draws the answer. grafana stores no metrics of its own.

---

## 5. Introduction to GitOps

the normal way to deploy is `kubectl apply` from your laptop. the problem is nobody can tell afterwards what is actually running or who changed it.

gitops moves the desired state into git and puts a controller in the middle:

```
developer -> git -> argo cd -> kubernetes
```

the README says to apply the demo manifest by hand once, just to see what is being deployed:

```bash
kubectl apply -f app/
kubectl get deployment session20-app
kubectl get pods -l app=session20-app
```

![manual apply](screenshots/Screenshot%202026-10-07%20175713.png)

`session20-app   2/2   2   2` - two nginx pods, applied manually. this is the thing i am about to stop doing, because from section 7 onwards argo cd applies these same two files for me.

---

## 6. Git as Source of Truth

i copied `gitops-repo/` to my home folder first so i did not create a git repo inside a git repo.

```bash
git init -b main
git add .
git commit -m "Add session 20 application manifests"
```

![git init and commit](screenshots/Screenshot%202026-10-07%20175801.png)

then i changed the desired state - replicas 2 to 3 - and looked at the diff before committing:

```bash
sed -i 's/replicas: 2/replicas: 3/' app/deployment.yaml
git diff
git commit -am "Scale application to three replicas"
git log --oneline
```

![git diff and history](screenshots/Screenshot%202026-10-07%20175807.png)

```diff
-  replicas: 2
+  replicas: 3
```

```
119ee83 (HEAD -> main) Scale application to three replicas
7887b07 Add session 20 application manifests
```

that two line history is the whole point. "who scaled the app and when" is now a `git log` instead of a guess, and a rollback is just checking out the earlier commit - the old desired state is still there.

note this repo is only git. nothing has touched kubernetes yet - git holds the **desired** state, the cluster holds the **actual** state, and the two stay disconnected until argo cd joins them.

---

## 7. Argo CD

```bash
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

![argocd install](screenshots/Screenshot%202026-10-07%20175830.png)

one url installs the whole thing - CRDs, 5 deployments, a statefulset and a set of network policies, all `serverside-applied`.

```bash
kubectl get pods -n argocd
```

![argocd pods](screenshots/Screenshot%202026-10-07%20180114.png)

all 7 pods `Running`. the images are big so this took a couple of minutes on my machine.

### pointing it at my own repo

the repo's `argocd-application.yaml` points at the instructor's `gitops-demo` repo. i wrote my own Application instead ([`argocd-apps/session20-app.yaml`](argocd-apps/session20-app.yaml)) pointing at **my** fork, at the manifest folder from section 5, and kept the Application file itself outside that path so argo cd does not try to manage itself:

```yaml
source:
  repoURL: https://github.com/piroBeastie/devops-heros.git
  targetRevision: main
  path: session20-monitoring-observability-gitops/05-introduction-to-gitops/app
destination:
  namespace: session20
syncPolicy:
  automated:
    prune: true
    selfHeal: true
  syncOptions:
    - CreateNamespace=true
```

```bash
kubectl apply -f argocd-apps/session20-app.yaml
kubectl get applications -n argocd
kubectl get all -n session20
```

![argocd application synced](screenshots/Screenshot%202026-10-07%20180220.png)

```
NAME            SYNC STATUS   HEALTH STATUS
session20-app   Synced        Healthy

pod/session20-app-75879b6878-g7khd   1/1   Running
pod/session20-app-75879b6878-wkqxf   1/1   Running
deployment.apps/session20-app        2/2   2   2
service/session20-app                ClusterIP   10.106.229.82   80/TCP
```

i never ran `kubectl apply` on the deployment or the service. argo cd read them out of github and created them, plus the `session20` namespace because of `CreateNamespace=true`.

### the UI

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

my browser refused the self-signed certificate, so instead of fighting the warning i turned TLS off on the server, which is the documented thing to do for a local lab:

```bash
kubectl -n argocd patch configmap argocd-cmd-params-cm --type merge -p '{"data":{"server.insecure":"true"}}'
kubectl -n argocd rollout restart deployment argocd-server
kubectl port-forward svc/argocd-server -n argocd 8080:80
```

![argocd ui](screenshots/Screenshot%202026-10-07%20180654.png)

![argocd app tree](screenshots/Screenshot%202026-10-07%20180712.png)

the detail view is the part i like. it shows **Synced to main (c0b661a)** and names the commit author and message - `Nanak <nanak006chahal@gmail.com>`, `session16: ci/cd simulations, local...`. the cluster is annotated with the exact git commit that produced it, which is the audit trail section 6 was talking about. the tree below shows the Application owning the service and the deployment.

### the app itself

```bash
kubectl port-forward svc/session20-app -n session20 8081:80
```

![nginx welcome](screenshots/Screenshot%202026-10-07%20180731.png)

nginx, running in the cluster, deployed from a file in github that i never applied by hand.

### self-healing

this is the best demo in the session. git says 2 replicas, so i broke that on purpose:

```bash
kubectl scale deployment session20-app -n session20 --replicas=1
kubectl get deploy session20-app -n session20
# wait 20 seconds
kubectl get deploy session20-app -n session20
kubectl describe application session20-app -n argocd | tail -7
```

![self heal](screenshots/Screenshot%202026-10-07%20180428.png)

```
session20-app   1/1   1   1      <- right after my scale command
session20-app   2/2   2   2      <- 20 seconds later
```

and the Application events explain what happened in between:

```
Updated sync status: Synced -> OutOfSync
Updated health status: Healthy -> Progressing
Partial sync operation to c0b661aa... succeeded
Updated sync status: OutOfSync -> Synced
```

argo cd noticed the cluster no longer matched git, started an automated sync and put it back. my `kubectl scale` was undone in under 20 seconds - the first time i tried it, it healed so fast i could not even catch the 1 replica in between.

the lesson: once an app is under gitops with `selfHeal: true`, **editing the cluster directly does nothing permanent**. if you want 1 replica you change the file in git. that is what "git is the source of truth" means in practice.

---

## Viva questions

1. **monitoring vs observability** - monitoring watches known signals and alerts; observability is having enough data to answer questions you did not plan for.
2. **metrics vs logs vs traces** - numbers over time / individual events / one request's journey across services.
3. **what is prometheus?** a time-series database that pulls metrics from targets on a schedule and answers PromQL queries.
4. **what is grafana?** the visualisation layer - it queries data sources like prometheus and draws dashboards. it does not store metrics.
5. **what is gitops?** keeping the desired state of the system in git and letting a controller apply it, instead of deploying by hand.
6. **why is git the source of truth?** history, diffs, review, blame and rollback for free, and one place that is authoritative.
7. **what does argo cd do?** it watches a git repo, compares it with the cluster and applies the difference.
8. **desired state** - what the yaml in git says should exist.
9. **actual state** - what is really running in the cluster right now.
10. **reconciliation** - the loop that compares the two and makes actual match desired.
11. **self-healing** - reconciliation undoing manual changes made outside git, like my `kubectl scale`.
12. **replicas 2 -> 3 in git** - argo cd sees the repo changed (it polls every ~3 minutes, or you hit Refresh), marks the app OutOfSync, syncs, and a third pod starts. no kubectl involved.
