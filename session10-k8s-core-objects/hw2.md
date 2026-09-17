# Session 11 HW - Deployments, Pod Lifecycle and Troubleshooting

## Task 1 & 2: Run deployment.yaml and deployment-v2.yaml

```
kubectl apply -f deployment/deployment-v1.yaml
kubectl apply -f deployment/deployment-v2.yaml
kubectl rollout status deployment/yatri-backend
kubectl rollout history deployment/yatri-backend
```

![Screenshot 1](screenshots/Screenshot%202026-09-17%20233526.png)

v2 did a rolling update - old pods were removed one by one and new pods came up, so the app never went fully down. rollout history shows revision 1 and 2.

## Task 3: Pod lifecycle files

applied the whole `pod-lifecycle` folder at once and then checked the status of all the pods

```
kubectl apply -f pod-lifecycle/
kubectl get pods | grep lifecycle
```

![Screenshot 2](screenshots/Screenshot%202026-09-17%20233629.png)

different stages i got in the output:

| pod | status | why |
|---|---|---|
| lifecycle-running | Running | normal pod, container is running |
| lifecycle-pending | Pending | it asks for 9Gi memory which my node does not have, so the scheduler can't place it |
| lifecycle-succeeded | Completed | the command finished with exit code 0 and restartPolicy is not Always |
| lifecycle-failed | Error | command exited with a non zero code |
| lifecycle-crashloop | Error / CrashLoopBackOff | container keeps crashing so kubelet restarts it again and again with increasing delay (restarts = 2) |
| lifecycle-image-error | ErrImagePull / ImagePullBackOff | the image does not exist so it cannot be pulled |
| lifecycle-startup | 0/1 Running | container is running but the startup probe has not passed yet so it is not ready |
| lifecycle-multi-container | 2/2 Running | 2 containers in one pod |

## Task 4: Troubleshooting exercise

### File 1 - broken-image.yaml

applied it on the running deployment. the image tag `non-existent-tag-v999` does not exist.

![Screenshot 3](screenshots/Screenshot%202026-09-17%20233724.png)

the new pod went to **ImagePullBackOff** and the rollout got stuck (`rollout status` timed out). but because the file uses `maxUnavailable: 0`, the 3 old pods stayed **Running**, so the app did not go down.

checked the reason with describe and then fixed it with rollout undo

![Screenshot 4](screenshots/Screenshot%202026-09-17%20233754.png)

describe showed: `Failed to pull image "yatri-backend:non-existent-tag-v999" ... pull access denied, repository does not exist`. after `kubectl rollout undo` the deployment went back to the working image and all 3 pods are Running again.

### File 2 - selector-mismatch.yaml

here the bug is one word - `selector.matchLabels` says `app: correct-app-name` but the pod template label says `app: wrong-app-name`.

![Screenshot 5](screenshots/Screenshot%202026-09-17%20233810.png)

apply failed with an error from the api server itself (no pod was even created):

```
The Deployment "selector-error-demo" is invalid: spec.template.metadata.labels:
Invalid value: {"app":"wrong-app-name"}: `selector` does not match template `labels`
```

**fix:** changed `wrong-app-name` to `correct-app-name` in the template labels and applied again, then it was created. the selector and the pod template labels must always be the same, otherwise the deployment would not be able to find its own pods.
