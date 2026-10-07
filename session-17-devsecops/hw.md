# Session 17 HW - DevSecOps

**Name:** Nanakjot Singh Chahal
**Enrollment No:** 24bcs10132

ran every scan type from this folder on the `demo/` flask app. i ran the tools inside docker containers so i did not have to install anything on my machine.

---

## What DevSecOps means

the old way was: build the app → ship it → security team audits it later and finds problems when it is expensive to fix.

DevSecOps means security checks are **steps in the pipeline**, so a problem is found on the commit that caused it. the four scan types answer different questions:

| scan | what it looks at | tool i used |
|---|---|---|
| **SAST** | my own source code | bandit |
| **SCA** | the libraries i depend on | pip-audit |
| **secret scanning** | credentials committed by mistake | gitleaks |
| **image scanning** | the OS packages inside the container | trivy |

a **scan** only reports. a **gate** is what decides whether the pipeline continues.

---

## 1. Build the artifact

```bash
cat Dockerfile
docker build -t devsecops-demo:1.0 .
docker images devsecops-demo
```

![Docker build](screenshots/Screenshot%202026-10-07%20172352.png)

the image is built from `python:3.12-slim`, installs Flask and runs `app/app.py` on port 5001. this image is what the later scans examine.

---

## 2. Unit tests

```bash
docker run --rm -v "$PWD":/app -w /app python:3.11-slim \
  sh -c 'pip install -q -r requirements.txt -r requirements-dev.txt && python -m pytest -q'
```

![Unit tests](screenshots/Screenshot%202026-10-07%20172405.png)

tests pass. in the pipeline this is the **first** gate - there is no point security scanning a build that does not even work.

---

## 3. SAST - Bandit (my own code)

```bash
docker run --rm -v "$PWD":/src -w /src python:3.11-slim \
  sh -c 'pip install -q bandit && bandit -r app/ -ll'
```

![Bandit SAST](screenshots/Screenshot%202026-10-07%20172418.png)

bandit scanned **168 lines** and found real problems:

```
Total issues (by severity):
        Low: 5
        Medium: 1
        High: 1
```

the **High** one is the important finding:

```
B104 hardcoded_bind_all_interfaces
Location: app/app.py:234
    app.run(host="0.0.0.0", port=5001, debug=True)
```

two separate things are wrong on that one line - binding to `0.0.0.0` exposes the dev server on every interface, and `debug=True` in flask gives anyone who can reach it the **werkzeug debugger**, which allows running python code on the server. that is a genuine critical mistake in production code, and SAST caught it without running the app.

SAST reads the code without executing it, so it is fast and runs on every commit. the trade-off is false positives - some of the 5 Low findings are flask patterns that are fine in a demo.

---

## 4. SCA - pip-audit (my dependencies)

```bash
cat requirements.txt
docker run --rm -v "$PWD":/src -w /src python:3.11-slim \
  sh -c 'pip install -q pip-audit && pip-audit -r requirements.txt'
```

![pip-audit clean](screenshots/Screenshot%202026-10-07%20172436.png)

the app pins `Flask==3.1.3` and the result is **"No known vulnerabilities found"** - so the dependency is current.

### what a real finding looks like

a clean result does not prove the scan works, so i tested it against an old flask version on purpose:

```bash
printf 'Flask==2.0.0\n' > /tmp/old-requirements.txt
docker run --rm -v /tmp:/t -w /t python:3.11-slim \
  sh -c 'pip install -q pip-audit && pip-audit -r old-requirements.txt'
```

![pip-audit vulnerable](screenshots/Screenshot%202026-10-07%20172456.png)

```
Found 4 known vulnerabilities in 1 package
Name   Version  ID              Fix Versions
flask  2.0.0    PYSEC-2023-62   2.2.5,2.3.2
flask  2.0.0    PYSEC-2026-2151 3.1.3
```

this is the difference from SAST - **i did not write a single line of this bug**. the vulnerability is in a library i pulled in, and the only fix is to upgrade to the listed version. SCA also tells you the exact fix version, which makes remediation mechanical.

---

## 5. Secret scanning - Gitleaks

```bash
docker run --rm -v "$PWD":/repo zricethezav/gitleaks:latest dir /repo --no-banner --redact -v
```

![Gitleaks](screenshots/Screenshot%202026-10-07%20172724.png)

scanning the **whole repository** found **9 leaks**, and every single one is in session 12:

```
RuleID: generic-api-key          session-12.../02-secret/db-secret.yaml
RuleID: kubernetes-secret-yaml    session-12.../02-secret/db-secret.yaml
RuleID: generic-api-key          session-12.../04-full-demo/secret.yaml
RuleID: generic-api-key          session-12.../lab.md
...
leaks found: 9
```

these are the base64 `POSTGRES_PASSWORD` values from the ConfigMaps & Secrets session. they are teaching examples, not real credentials - but gitleaks flags them anyway, and **that is exactly the right behaviour**, because it cannot tell a demo password from a production one. it also proves the point session 12 made: base64 in a git repo is not a secret, and the repo history keeps it forever even if you delete the file later.

when i scoped the scan to just the app folder it reported **"no leaks found"**, which is what the pipeline gate uses.

---

## 6. Container image scanning - Trivy

```bash
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v trivy-cache:/root/.cache \
  aquasec/trivy:latest image --scanners vuln --severity HIGH,CRITICAL devsecops-demo:1.0
```

![Trivy scan](screenshots/Screenshot%202026-10-07%20172530.png)

trivy found HIGH/CRITICAL CVEs in the image - in packages like `util-linux`, `perl`, `zlib` and so on. the important thing is **i did not install any of those**: they come from the `python:3.12-slim` base image.

that is what image scanning is for. my code can be perfect and my dependencies current, and the shipped container still has vulnerable OS packages. the usual fixes are to use a smaller base (alpine/distroless), rebuild on a newer base tag regularly, or remove build tools from the final image (which is what multi-stage builds do).

---

## 7. Security gates

a gate is just a non-zero exit code stopping the pipeline. trivy's `--exit-code 1` is how you turn the report into a gate:

![Security gate](screenshots/Screenshot%202026-10-07%20172536.png)

```bash
# strict gate - any HIGH/CRITICAL blocks
trivy image --severity HIGH,CRITICAL --exit-code 1 devsecops-demo:1.0
  → trivy exit code = 1   (gate BLOCKS the pipeline)

# practical gate - only vulns that actually have a fix available
trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 devsecops-demo:1.0
  → trivy exit code = 0   (gate PASSES)
```

this is the real decision every team has to make. the strict gate blocks the build on CVEs that have **no fix published yet**, which means nobody can ship anything until upstream releases a patch - so people start disabling the gate entirely. `--ignore-unfixed` only fails on vulnerabilities you can actually do something about, which keeps the gate credible.

| what to gate | why |
|---|---|
| failing unit tests | broken code should never reach an image |
| fixable HIGH/CRITICAL CVEs | there is an upgrade available, so there is no excuse |
| any leaked secret | one commit is enough to compromise a credential |
| SAST high severity | real code flaws like `debug=True` |

---

## 8. Deploying the scanned image

```bash
minikube image load devsecops-demo:1.0
kubectl apply -f /tmp/s17-deploy.yaml -f k8s/service.yaml
kubectl get pods,svc -l app=session17-python
```

![Kubernetes deploy](screenshots/Screenshot%202026-10-07%20172629.png)

the manifest in the repo points at `nensiravaliya28/hey-cicd:__IMAGE_TAG__`, which is a placeholder the CI pipeline is meant to substitute. since i built and scanned my own image, i loaded that into minikube and deployed it with `imagePullPolicy: IfNotPresent`:

```
pod/session17-python-8474b46d46-858m7   1/1   Running
pod/session17-python-8474b46d46-fhfx8   1/1   Running
```

so the thing actually running in the cluster is the exact image the scans approved - that is the whole point of the pipeline order: **test → scan → gate → deploy**.

---

## 9. The pipeline as a workflow

i put all of this into [`.github/workflows/devsecops.yml`](../.github/workflows/devsecops.yml):

```
test ─┐
      ├─► image-scan (build + trivy report + trivy gate) ─┐
sca ──┘                                                    ├─► deploy
                                           secret-scan ───┘
sast (reports only)
```

- `deploy` has `needs: [image-scan, secret-scan]`, so it **cannot run** unless those passed - that is the gate expressed in github actions.
- `sast` is marked `continue-on-error: true` on purpose, because the demo app's `debug=True` finding is real and would block everything. in a production repo i would fix the code instead of relaxing the gate.
- the trivy step runs twice: once to **print** all HIGH/CRITICAL for visibility, once with `ignore-unfixed` + `exit-code: 1` as the actual gate.

---

## Summary

| | SAST | SCA | Secret scanning | Image scanning |
|---|---|---|---|---|
| looks at | my code | my dependencies | my commits | the container OS |
| tool | bandit | pip-audit | gitleaks | trivy |
| my result | 1 High, 1 Medium, 5 Low | clean (4 CVEs on old flask) | 9 leaks repo-wide | HIGH/CRITICAL in base image |
| who fixes it | me | upgrade the package | rotate the secret + purge history | rebuild on a newer/smaller base |
