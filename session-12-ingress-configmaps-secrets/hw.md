# Session 12 HW - Ingress, ConfigMaps & Secrets

**Name:** Nanakjot Singh Chahal
**Enrollment No:** 24bcs10132

the manifests are the ones in this folder

---

## Task 1: ConfigMap for non-sensitive config

a ConfigMap keeps the environment specific settings out of the image, so the same image can run in dev/staging/production.

```bash
kubectl apply -f 01-configmap/app-config.yaml
kubectl describe configmap yatri-app-config
kubectl get configmap yatri-app-config -o jsonpath='{.data.ENVIRONMENT}'
```

![ConfigMap](01-configmap/Screenshot%202026-09-18%20004040.png)

describe shows all 5 keys (`ENVIRONMENT`, `LOG_LEVEL`, `PORT`, `DEFAULT_CURRENCY`, `MAX_BOOKING_DAYS`) with their values in plain text, and the jsonpath query returned `production`.

---

## Task 2: ConfigMap update does NOT change running pods

```bash
kubectl patch configmap yatri-app-config --type merge -p '{"data":{"ENVIRONMENT":"staging"}}'
kubectl get configmap yatri-app-config -o jsonpath='{.data.ENVIRONMENT}'      # staging
kubectl exec deploy/yatri-backend -- env | grep ENVIRONMENT                   # still production
kubectl rollout restart deployment/yatri-backend
kubectl exec deploy/yatri-backend -- env | grep ENVIRONMENT                   # now staging
```

![ConfigMap immobility](01-configmap/Screenshot%202026-09-18%20004109.png)

this is the important part: the ConfigMap said **staging** but the running pod still said `ENVIRONMENT=production`.

**why:** with `envFrom`/`env` the values are copied into the container's environment **once**, when the container starts. environment variables of a running process cannot be changed from outside. so the pod keeps the old value until it is replaced.

after `kubectl rollout restart` (which is a normal rolling update, so no downtime) the new pods read the ConfigMap again and showed `ENVIRONMENT=staging`.

if i needed live updates without a restart i would have to mount the ConfigMap as a **volume** instead of env vars - mounted files do get updated (after a sync delay), but the app has to re-read the file.

---

## Task 3: Secret and base64

```bash
kubectl apply -f 02-secret/db-secret.yaml
kubectl describe secret yatri-db-secret
kubectl get secret yatri-db-secret -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 --decode
```

![Secret](02-secret/Screenshot%202026-09-18%20004047.png)

`describe` only shows the **byte lengths**, not the values, so it is safe to paste in a ticket. but anyone who can read the secret can decode it in one command - i got back `secretpassword` and `yatri_admin`.

**base64 is encoding, not encryption.** it is there so binary data can sit inside yaml, nothing more. by default secrets are stored in etcd base64 encoded but **not** encrypted, so a real cluster needs encryption at rest + RBAC so normal users cannot read secrets.

---

## Task 4: The trailing newline gotcha

```bash
echo 'secretpassword' | xxd | tail -2
echo -n 'secretpassword' | xxd | tail -2
echo 'secretpassword' | base64
echo -n 'secretpassword' | base64
```

![Base64 newline gotcha](02-secret/Screenshot%202026-09-18%20004052.png)

`xxd` shows it clearly - plain `echo` puts a **0a** byte (`\n`) at the end, `echo -n` does not:

```
echo 'secretpassword'    -> 7365 6372 6574 7061 7373 776f 7264 0a   <- extra 0a
echo -n 'secretpassword' -> 7365 6372 6574 7061 7373 776f 7264      <- clean
```

| command | base64 output |
|---|---|
| `echo "secretpassword" \| base64` | `c2VjcmV0cGFzc3dvcmQK` (wrong - the trailing `K` is the newline) |
| `echo -n "secretpassword" \| base64` | `c2VjcmV0cGFzc3dvcmQ=` (correct, and this is what the repo's `db-secret.yaml` uses) |

so the wrong one stores the password as `secretpassword\n`. the pod gets that env var, sends it to postgres, and authentication fails with "password authentication failed" while the password *looks* completely correct in the yaml. always `echo -n`, or use `kubectl create secret generic --from-literal=` which handles it for you.

---

## Task 5: How secrets are handled in real companies

committing a `Secret` yaml to git is bad even though it is base64:

- base64 is not encryption, anyone with repo access can decode it
- git keeps **history**, so deleting the file later does not remove the secret from old commits
- there is no rotation, no audit of who read it, and every environment ends up with the same hardcoded value

what is used instead:

```
AWS Secrets Manager / Azure Key Vault / HashiCorp Vault
            │
            ▼
External Secrets Operator  (or Vault Agent Injector)
            │   watches the external store, syncs into the cluster
            ▼
    Kubernetes Secret  (created at runtime, never in git)
            │
            ▼
        Pod  (env var or mounted volume)
```

- **External Secrets Operator (ESO):** i commit only an `ExternalSecret` object that says *which key* to fetch. the operator pulls the real value from AWS/Azure/Vault and creates the actual Secret in the cluster. rotating the value in the cloud updates the cluster automatically.
- **Vault Agent Injector:** a sidecar fetches secrets at pod start and writes them to a shared in-memory volume, so nothing is ever stored in etcd.
- **CI/CD:** GitHub Actions secrets or Azure DevOps variable groups hold the values, and the pipeline injects them at deploy time (`kubectl create secret ... --from-literal=$PASSWORD`). the manifests in the repo only contain references.

```bash
kubectl get crds | grep -i secret || echo "Standard native secrets in use"
```

my minikube has no such operator installed, so it is using plain native secrets.

---

## Task 6: ConfigMap + Secret injected together

`backend.yaml` uses both styles at once - `envFrom.configMapRef` pulls in **all** the ConfigMap keys, and `env.valueFrom.secretKeyRef` picks **specific** secret keys.

```bash
kubectl apply -f 04-full-demo/configmap.yaml -f 04-full-demo/secret.yaml -f 04-full-demo/backend.yaml
kubectl rollout status deployment/yatri-backend
kubectl exec deploy/yatri-backend -- env | grep -E 'ENVIRONMENT|LOG_LEVEL|POSTGRES|DEFAULT_CURRENCY'
```

![Combined injection](04-full-demo/Screenshot%202026-09-18%20004100.png)

inside the container both sets are there together:

```
ENVIRONMENT=production      <- from ConfigMap (envFrom)
LOG_LEVEL=INFO              <- from ConfigMap
DEFAULT_CURRENCY=INR        <- from ConfigMap
POSTGRES_USER=yatri_admin   <- from Secret (secretKeyRef)
POSTGRES_PASSWORD=secretpassword
POSTGRES_DB=yatri_production_db
```

`envFrom` is convenient but it dumps every key; `secretKeyRef` is explicit which is what you want for credentials, so a pod only gets the exact secret keys it needs.

---

## Task 7: Ingress resource vs Ingress controller

| | Ingress resource | Ingress controller |
|---|---|---|
| what it is | a yaml object (rules: host, path, service, tls) | an actual pod running a reverse proxy (nginx, traefik, haproxy) |
| what it does | **nothing by itself** - it is just the routing config stored in etcd | watches the api server for Ingress objects, generates its own config (`nginx.conf`) and reloads, then routes real traffic |
| how many | one per app/team usually | usually one per cluster |
| analogy | the instructions | the person who follows them |

so if you apply an Ingress without a controller installed, nothing happens - the object exists, ADDRESS stays empty and no traffic is routed.

```bash
kubectl api-resources | grep -i ingress
```

![Ingress api resources](03-ingress/Screenshot%202026-09-18%20004115.png)

`ingresses` and `ingressclasses` are built into the `networking.k8s.io` api, but the controller is a separate component you install.

---

## Task 8: Enable the NGINX Ingress Controller

```bash
minikube addons enable ingress
kubectl get pods -n ingress-nginx
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s
kubectl get service -n ingress-nginx ingress-nginx-controller
```

![Ingress controller](03-ingress/Screenshot%202026-09-18%20004124.png)

`ingress-nginx-controller` is **1/1 Running** and `kubectl wait` printed `condition met`. the 2 admission jobs show `Completed` - they only run once to set up the validating webhook.

---

## Task 9: Local DNS with /etc/hosts

the ingress routes by hostname, so my machine has to resolve `yatri.local` to the cluster ip.

```bash
minikube ip
echo "192.168.49.2  yatri.local portal.campus.local api.campus.local" | sudo tee -a /etc/hosts
getent hosts yatri.local
```

![Hosts file](03-ingress/Screenshot%202026-09-18%20005216.png)

note for wsl: `/etc/hosts` is regenerated by wsl on boot, so this entry has to be added again after a restart (or set `generateHosts = false` in `/etc/wsl.conf`).

---

## Task 10: Path based routing

one host `yatri.local`, two paths: `/` goes to the frontend and `/api` goes to the backend. the backend rule uses `path: /api(/|$)(.*)` with the annotation `rewrite-target: /$2`, so `/api/foo` reaches the backend as `/foo`.

```bash
kubectl apply -f 04-full-demo/frontend.yaml -f 03-ingress/ingress-routes.yaml
kubectl get ingress yatri-ingress
kubectl describe ingress yatri-ingress
curl http://yatri.local/
curl http://yatri.local/api/
```

![Path based routing](03-ingress/Screenshot%202026-09-18%20005223.png)

the rules table shows both paths with their backend pod ips, and:

- `http://yatri.local/` → `<title>Welcome to nginx!</title>` (frontend)
- `http://yatri.local/api/` → the python backend printing the ConfigMap and Secret values

both on the **same ip and same port 80** - the ingress decides by host+path.

---

## Task 11: Host based routing

the ingress picks the rule using the HTTP `Host` header, so i can test different hostnames against the same ip without touching dns:

```bash
curl -H 'Host: yatri.local' http://$(minikube ip)/
curl -H 'Host: yatri.local' http://$(minikube ip)/api/
curl -H 'Host: unknown.local' http://$(minikube ip)/
```

![Host based routing](03-ingress/Screenshot%202026-09-18%20005054.png)

with `Host: yatri.local` both routes work, and with a host that has no rule the ingress returns **404** (its default backend). that proves the routing really is based on the Host header, not the ip.

---

## Task 12: Hybrid routing (host + path in one ingress)

`ingress-tls.yaml` has two hosts in one manifest, and each host has its own path rules:

```bash
kubectl get ingress
kubectl describe ingress campus-ingress-tls
```

![Hybrid ingress](03-ingress/Screenshot%202026-09-18%20005446.png)

| host | path | service |
|---|---|---|
| `portal.campus.local` | `/()(.*)` | yatri-frontend-service |
| `api.campus.local` | `/api(/\|$)(.*)` | yatri-backend-service |

and `kubectl get ingress` shows both ingresses sharing the same ADDRESS `192.168.49.2`, one on port 80 and the TLS one on `80, 443`.

---

## Task 13: TLS / HTTPS termination

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt \
  -subj "/CN=campus.local/O=CampusDevOps" \
  -addext "subjectAltName=DNS:campus.local,DNS:portal.campus.local,DNS:api.campus.local"
kubectl create secret tls campus-tls-cert --cert=tls.crt --key=tls.key
kubectl apply -f 03-ingress/ingress-tls.yaml
```

![TLS secret](03-ingress/Screenshot%202026-09-18%20005432.png)

the secret type is `kubernetes.io/tls` with **2** keys (`tls.crt` + `tls.key`).

```bash
curl -k -sv --resolve portal.campus.local:443:$(minikube ip) https://portal.campus.local/
curl -k -s  --resolve api.campus.local:443:$(minikube ip) https://api.campus.local/api/
```

![TLS verification](03-ingress/Screenshot%202026-09-18%20005439.png)

result: **HTTP/2 200 over TLSv1.3**, and the certificate served is `subject: CN=campus.local; O=CampusDevOps` - my own cert. `-k` is needed because it is self signed.

**one problem i hit:** the first time i generated the cert with only `-subj "/CN=campus.local"` and nginx served its own *"Kubernetes Ingress Controller Fake Certificate"* instead of mine. the reason is that the certificate has to actually match the ingress host - `CN=campus.local` does not cover `portal.campus.local`. after regenerating it with `-addext "subjectAltName=DNS:portal.campus.local,DNS:api.campus.local"` the real certificate was served.

TLS is terminated **at the ingress controller** - traffic from the controller to the pods is plain http inside the cluster.

---

## Task 14: Full demo automation scripts

```bash
grep -c '^---' 04-full-demo/backend.yaml     # multi document yaml
bash 04-full-demo/run-demo.sh
```

![run-demo failure](04-full-demo/Screenshot%202026-09-18%20005656.png)

`backend.yaml` has `---` separators, which lets one file hold both the Deployment and its Service (`kubectl apply -f` applies every document in the file).

**the script failed the first time:**

```
: invalid option name.sh: line 4: set: pipefail
```

that is because i cloned the repo on **windows**, so git checked the file out with **CRLF** line endings and bash read `pipefail\r` as the option name. `file run-demo.sh` confirmed `with CRLF line terminators`. fixed it with:

```bash
sed -i 's/\r$//' 04-full-demo/run-demo.sh 04-full-demo/cleanup.sh
```

i also added a `.gitattributes` with `*.sh text eol=lf` so shell scripts stay LF and this cannot happen again.

after the fix it ran fully:

![run-demo success](04-full-demo/Screenshot%202026-09-18%20005738.png)

then the audit and teardown:

```bash
kubectl get configmap,secret,ingress,deploy,svc | grep -E 'yatri|campus'
bash 04-full-demo/cleanup.sh
kubectl get ingress yatri-ingress
```

![Audit and cleanup](04-full-demo/Screenshot%202026-09-18%20005746.png)

the audit shows the whole stack together - ConfigMap, 2 Secrets, 2 Ingresses, 2 Deployments (2/2 each) and 2 Services. `cleanup.sh` deleted them in reverse order and `kubectl get ingress yatri-ingress` then returned **NotFound**, so the teardown is complete.
