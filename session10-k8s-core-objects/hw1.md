# Session 10 HW - Pods, ReplicaSet, Deployment, DaemonSet, StatefulSet

ran all the files from the `k8s-core-objects` folder on my minikube cluster.

## What these things mean

### Pod
smallest unit in kubernetes. one pod can have more than one container and they share the same network and storage. `pod.yml` has 2 containers (nginx + busybox logger) so the pod shows 2/2.

### ReplicaSet
makes sure the given number of identical pods are always running. it uses `matchLabels` to find its pods. if a pod is deleted or crashes, the replicaset creates a new one. normally we don't make replicasets directly, deployment makes them for us.

### Deployment
one level above replicaset. it creates and manages replicasets for us and gives rolling updates, rollback (`kubectl rollout undo`), scaling and pause. used for stateless apps like web servers and apis.

### DaemonSet
runs exactly **one pod on every node**. when a new node joins the cluster the daemonset automatically puts a pod on it. used for node level agents - log collectors (fluentd), monitoring agents (node-exporter), network plugins (calico, kube-proxy).

### StatefulSet
used for stateful apps. difference from deployment:
- pod names are fixed and in order - `mysql-0`, `mysql-1`, `mysql-2` (not random hash)
- pods are created in order 0,1,2 and deleted in reverse order
- every pod gets its **own** PVC from `volumeClaimTemplates`, and the volume stays with that pod name even after restart
- needs a headless service for pod to pod dns

### Where are StatefulSets used
databases and anything which has its own data or identity - mysql/postgres clusters, mongodb, cassandra, kafka, zookeeper, elasticsearch, redis cluster.

## Output

### Pod
![Screenshot 1](screenshots/Screenshot%202026-09-17%20233141.png)

### ReplicaSet
deleted one pod on purpose and the replicaset immediately made a new one (3 pods again)

![Screenshot 2](screenshots/Screenshot%202026-09-17%20233213.png)

### Deployment
deployment created a replicaset and the replicaset created the 3 pods

![Screenshot 3](screenshots/Screenshot%202026-09-17%20233235.png)

### DaemonSet
only 1 pod because minikube has only 1 node. if there were 3 nodes there would be 3 pods

![Screenshot 4](screenshots/Screenshot%202026-09-17%20233303.png)

### StatefulSet
pods came up in order mysql-0, mysql-1, mysql-2 and each one got its own 5Gi PVC

![Screenshot 5](screenshots/Screenshot%202026-09-17%20233428.png)
