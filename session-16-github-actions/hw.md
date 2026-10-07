# Session 16 HW - CI/CD with GitHub Actions

**Name:** Nanakjot Singh Chahal
**Enrollment No:** 24bcs10132

---

## CI vs CD

| | CI (Continuous Integration) | CD (Continuous Delivery / Deployment) |
|---|---|---|
| what it does | every push is built, linted and tested automatically | the tested build is released/deployed automatically |
| question it answers | "did my change break anything?" | "can we ship it, and ship it safely?" |
| runs | on every commit / PR | after CI passes |
| output | a verified artifact + test report | a running version in staging/production |

**Delivery vs Deployment:** continuous *delivery* makes every passing build ready to release but a human clicks the button; continuous *deployment* pushes it to production automatically with no human step.

### CI simulation

```bash
bash '01-ci-vs-cd/ci_simulation.sh'
```

![CI simulation](screenshots/Screenshot%202026-10-07%20171132.png)

the script walks through what a CI run actually does: checkout → set up runtime → lint → unit tests → coverage check. it only says "ready for CD" at the end, which is the point - CD never starts unless CI passed.

### CD simulation

```bash
bash '01-ci-vs-cd/cd_simulation.sh'
```

![CD simulation](screenshots/Screenshot%202026-10-07%20171139.png)

---

## Pipeline stages

```bash
bash '02-pipeline-concepts/pipeline_stages.sh'
```

![Pipeline stages](screenshots/Screenshot%202026-10-07%20171146.png)

a pipeline is just stages that run in order, and a failing stage stops the ones after it. the quality gates (lint / test / security scan) can run **in parallel** because they do not depend on each other, which is how real pipelines stay fast.

---

## Workflow basics

| term | meaning |
|---|---|
| **workflow** | a yaml file in `.github/workflows/` |
| **event / trigger** | what starts it - `push`, `pull_request`, `schedule`, `workflow_dispatch` |
| **job** | a group of steps that runs on one runner; jobs run in parallel unless you use `needs:` |
| **step** | one command (`run:`) or one reusable action (`uses:`) |
| **runner** | the machine executing the job (`runs-on: ubuntu-latest`) |
| **action** | a prebuilt step from the marketplace, e.g. `actions/checkout@v4` |
| **artifact** | files uploaded from a run (test reports, builds) so you can download them later |

my two workflows:

![Workflow files](screenshots/Screenshot%202026-10-07%20171208.png)

- **`.github/workflows/hello.yml`** - the simplest one. triggers on push to main, prints a message and the runner info from the built-in env vars (`$GITHUB_REPOSITORY`, `$GITHUB_REF_NAME`, `$GITHUB_SHA`, `$RUNNER_OS`).
- **`.github/workflows/ci.yml`** - the real pipeline: a `lint` job and a `test` job where test has `needs: lint`, so tests only run if flake8 passed. it also uploads the test report and coverage as **artifacts**.

i added `workflow_dispatch` to both so they can also be run manually from the Actions tab, and used `defaults.run.working-directory` so every step runs inside my app folder.

---

## The app under test

`session-16-github-actions/ci-demo/` has a small python module and its tests:

- `app.py` - `add`, `subtract`, `divide` (divide raises `ValueError` on zero)
- `tests/test_app.py` - 4 pytest tests including the divide-by-zero case
- `requirements.txt` - pytest, pytest-cov, flake8

### running the same pipeline locally first

before pushing i ran exactly what the CI job runs, inside a python container so my machine stays clean:

```bash
docker run --rm -v "$PWD":/app -w /app python:3.11-slim \
  sh -c 'pip install -q -r requirements.txt && flake8 app.py tests/ && python -m pytest tests/ -q --cov=app --cov-report=term-missing'
```

![Local CI run](screenshots/Screenshot%202026-10-07%20171201.png)

result: **flake8 clean, 4 passed, 100% coverage**. running it locally first is the habit - if it fails here it will fail in CI, and a failed CI run takes much longer to find out.

---

## Workflow run on GitHub

after pushing, both workflows ran by themselves on the `push` to main.

![Actions page](screenshots/Screenshot%202026-10-07%20171953.png)

the Actions tab shows **2 workflow runs, both green** on commit `c0b661a` - `Hello World #1` took 5s and `CI Pipeline #1` took 27s.

i also checked the result from the terminal using the GitHub API, which shows every job and step:

![Workflow run details](screenshots/Screenshot%202026-10-07%20171939.png)

```
WORKFLOW         STATUS      RESULT     COMMIT
Hello World      completed   success    c0b661aa
CI Pipeline      completed   success    c0b661aa

JOB: Code Lint   completed/success      JOB: Run Tests  completed/success
    Checkout code        success           Checkout code         success
    Set up Python        success           Set up Python         success
    Install lint tool    success           Install dependencies  success
    Run flake8           success           Run tests with cov.   success
                                           Upload test results   success
                                           Upload coverage rep.  success

ARTIFACT: test-results     354 bytes
ARTIFACT: coverage-report  546 bytes
```

things this proves:

- the **`needs: lint`** dependency worked - `Run Tests` only started after `Code Lint` finished green
- `actions/checkout@v4` and `actions/setup-python@v5` pulled the repo and installed python on the runner
- the **artifacts** were uploaded and are downloadable from the run page (`test-results` = the junit xml, `coverage-report` = coverage.xml)
- the extra `Post Set up Python` / `Post Checkout code` steps are the actions cleaning themselves up after the job - github adds those automatically

so the same pipeline i ran locally in a container also runs on github's `ubuntu-latest` runner on every push to main.
