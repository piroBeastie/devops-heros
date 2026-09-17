## LoadBalancer Service

this type asks the cloud provider (aws/gcp/azure) for a real load balancer and gives an external ip.

![LoadBalancer screenshot](Screenshot%202026-09-17%20235411.png)

on minikube the EXTERNAL-IP stays `<pending>` because there is no cloud provider to give a load balancer (for a real external ip we have to run `minikube tunnel`).

but a LoadBalancer service also allocates a NodePort (here `80:32687`), so i could still test it with `curl http://192.168.49.2:32687` and got the nginx page.
