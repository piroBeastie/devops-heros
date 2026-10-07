# Session 15 HW - Helm

**Name:** Nanakjot Singh Chahal
**Enrollment No:** 24bcs10132

helm v3.16.3 on my minikube cluster.

---

## What is Helm

helm is the **package manager for kubernetes**, like apt for ubuntu or npm for node.

without helm, deploying an app means applying 5-6 separate yaml files by hand, and for dev/staging/prod you copy paste those files and edit the values. with helm all of that becomes **one chart** plus a `values.yaml`, and you install it with one command.

| term | meaning |
|---|---|
| **Chart** | the package - templates + default values |
| **Release** | one installation of a chart in the cluster (you can install the same chart many times with different names) |
| **Values** | the settings that fill in the templates (`values.yaml` or `--set`) |
| **Revision** | every install/upgrade/rollback makes a new numbered revision |

### chart structure

```bash
helm version
ls 02-helm-charts/myapp
cat 02-helm-charts/myapp/Chart.yaml
ls 02-helm-charts/myapp/templates
```

![Helm chart structure](screenshots/Screenshot%202026-10-07%20170207.png)

| file | what it is |
|---|---|
| `Chart.yaml` | the chart's metadata - name, version, appVersion |
| `values.yaml` | default values that go into the templates |
| `templates/` | the yaml templates with `{{ }}` placeholders |
| `templates/_helpers.tpl` | reusable template snippets (naming, labels) |
| `.helmignore` | files to leave out when packaging |

---

## Lint and template (check before installing)

```bash
helm lint notes-chart
helm template notes-dev notes-chart
```

![Helm lint and template](screenshots/Screenshot%202026-10-07%20170216.png)

- `helm lint` checks the chart for mistakes - it returned **0 chart(s) failed**.
- `helm template` renders the templates locally and prints the final yaml **without installing anything**. this is the best way to see what helm will actually send to the cluster, and you can see the `{{ .Release.Name }}` placeholders have become `notes-dev`.

---

## helm install

```bash
helm install web-app ./app-chart
helm list
kubectl get pods -l app=web-app
```

![Helm install](screenshots/Screenshot%202026-10-07%20170441.png)

one command created the deployment and service. `helm list` shows the release at **REVISION 1**, status `deployed`, chart `app-chart-0.1.0`.

the chart's default values are `replicaCount: 1` and `image: nginx:1.24`, so 1 pod came up.

---

## helm upgrade

```bash
helm upgrade web-app ./app-chart --set replicaCount=3
kubectl get pods -l app=web-app
helm get values web-app
```

![Helm upgrade](screenshots/Screenshot%202026-10-07%20170515.png)

`--set replicaCount=3` overrides the value from the command line without editing any file, and the release moved to **REVISION 2** with 3 pods running.

`helm get values` shows only the **user supplied values** (`replicaCount: 3`) which is handy to see what was overridden vs what came from defaults.

difference worth remembering:

| command | behaviour |
|---|---|
| `helm install` | fails if the release already exists |
| `helm upgrade` | fails if the release does not exist |
| `helm upgrade --install` | installs if new, upgrades if it exists (what CI/CD uses) |

---

## helm rollback

first i broke the release on purpose with an image tag that does not exist:

```bash
helm install rollback-demo ../07-install-upgrade/app-chart
helm upgrade rollback-demo ../07-install-upgrade/app-chart --set image.tag=doesnotexist
kubectl get pods -l app=rollback-demo
helm history rollback-demo
```

![Helm broken upgrade](screenshots/Screenshot%202026-10-07%20170615.png)

the new pod went **ErrImagePull** while the old pod kept running, and `helm history` shows revision 1 `superseded` and revision 2 `deployed`.

note that helm still says "Happy Helming" and marks revision 2 as deployed - helm does not know the pod failed, because the deployment object was accepted. that is why you still check `kubectl get pods` after an upgrade.

```bash
helm rollback rollback-demo 1
kubectl get pods -l app=rollback-demo
helm history rollback-demo
```

![Helm rollback](screenshots/Screenshot%202026-10-07%20170654.png)

after the rollback the broken pod is gone and only the working one remains. the history now has a **revision 3** described as **"Rollback to 1"** - helm does not delete history, it adds a new revision that goes back to the old state. so you can always roll forward again.

---

## Mini project - notes-chart

```bash
helm install notes-dev notes-chart
kubectl get pods,svc,configmap -l app=notes-dev
```

![Helm mini project install](screenshots/Screenshot%202026-10-07%20170749.png)

one chart created all three objects at once - the deployment pod, the service and the configmap - all named after the release (`notes-dev-deploy`, `notes-dev-svc`, `notes-dev-config`).

### upgrading with a different values file

```bash
grep -E 'replicaCount|tag' notes-chart/values-prod.yaml
helm upgrade notes-dev notes-chart -f notes-chart/values-prod.yaml
kubectl get pods -l app=notes-dev
helm history notes-dev
helm uninstall notes-dev
```

![Helm mini project upgrade](screenshots/Screenshot%202026-10-07%20170828.png)

`values-prod.yaml` has `replicaCount: 3` and `tag: "1.25"`, so the upgrade went from 1 pod to **3 pods** on a newer image, and the release moved to revision 2.

this is the real reason helm is used: the **same chart** deploys to dev and prod, and only the values file changes. no copy pasted yaml per environment.

finally `helm uninstall notes-dev` removed everything the chart created in one command.

---

## Commands i used

| command | what it does |
|---|---|
| `helm version` | check the helm version |
| `helm lint <chart>` | check the chart for errors |
| `helm template <name> <chart>` | render the yaml locally without installing |
| `helm install <name> <chart>` | create a release |
| `helm list` | list releases |
| `helm upgrade <name> <chart> --set k=v` | change values |
| `helm upgrade -f values-prod.yaml` | upgrade using another values file |
| `helm get values <name>` | show user supplied values |
| `helm history <name>` | list all revisions |
| `helm rollback <name> N` | go back to revision N |
| `helm uninstall <name>` | delete the release and everything in it |
