# Lab: Helm

[Task Description](https://talks.timebertt.dev/platform-engineering/#/lab-helm)

## Overview

In this lab, we deploy the [podinfo](https://github.com/stefanprodan/podinfo) application using [Helm](https://helm.sh/), similar to the previous Kustomize lab, but with Helm-specific workflows.

We deploy two environments:
- Development: Namespace `podinfo-helm-dev`
- Production: Namespace `podinfo-helm-prod`, with the LoadBalancer service port set to `12001`

For simplicity, we store the Helm values in dedicated YAML files in the [`deploy/podinfo-helm`](../deploy/podinfo-helm) directory.
The common values applied for both environments are configured in `values.yaml`, while the environment-specific overrides are in `values-development.yaml` and `values-production.yaml`.

## Render the Chart

To get a preview of the rendered Kubernetes manifests, use the `helm template` command, e.g.:

```bash
helm template podinfo-dev oci://ghcr.io/stefanprodan/charts/podinfo \
  --namespace podinfo-helm-dev \
  --values deploy/podinfo-helm/values.yaml \
  --values deploy/podinfo-helm/values-development.yaml
```

## Install the Chart

Install the podinfo chart in both environments using the `helm install` command with the respective values files:

```bash
helm install podinfo-dev oci://ghcr.io/stefanprodan/charts/podinfo \
  --namespace podinfo-helm-dev --create-namespace \
  --values deploy/podinfo-helm/values.yaml \
  --values deploy/podinfo-helm/values-development.yaml

helm install podinfo-prod oci://ghcr.io/stefanprodan/charts/podinfo \
  --namespace podinfo-helm-prod --create-namespace \
  --values deploy/podinfo-helm/values.yaml \
  --values deploy/podinfo-helm/values-production.yaml
```

## Verify the Deployments

The results should look something like this:

```bash
$ helm ls -A
NAME        	NAMESPACE        	REVISION	UPDATED                             	STATUS  	CHART        	APP VERSION
podinfo-dev 	podinfo-helm-dev 	1       	2025-11-05 21:44:36.52511 +0100 CET 	deployed	podinfo-6.9.2	6.9.2
podinfo-prod	podinfo-helm-prod	1       	2025-11-05 21:44:37.598051 +0100 CET	deployed	podinfo-6.9.2	6.9.2

$ kubectl -n podinfo-helm-dev get deploy,po,svc -owide
NAME                          READY   UP-TO-DATE   AVAILABLE   AGE     CONTAINERS   IMAGES                                SELECTOR
deployment.apps/podinfo-dev   1/1     1            1           6m21s   podinfo      ghcr.io/stefanprodan/podinfo:latest   app.kubernetes.io/name=podinfo-dev

NAME                               READY   STATUS    RESTARTS   AGE     IP           NODE                         NOMINATED NODE   READINESS GATES
pod/podinfo-dev-77bf97cf75-jms7z   1/1     Running   0          6m21s   10.42.3.13   cluster-timebertt-worker-0   <none>           <none>

NAME                  TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)             AGE     SELECTOR
service/podinfo-dev   ClusterIP   10.43.18.89   <none>        9898/TCP,9999/TCP   6m21s   app.kubernetes.io/name=podinfo-dev

$ kubectl -n podinfo-helm-prod get deploy,po,svc -owide
NAME                           READY   UP-TO-DATE   AVAILABLE   AGE     CONTAINERS   IMAGES                               SELECTOR
deployment.apps/podinfo-prod   1/1     1            1           6m20s   podinfo      ghcr.io/stefanprodan/podinfo:6.9.0   app.kubernetes.io/name=podinfo-prod

NAME                                READY   STATUS    RESTARTS   AGE     IP           NODE                         NOMINATED NODE   READINESS GATES
pod/podinfo-prod-6475f96f98-mhcf9   1/1     Running   0          3m36s   10.42.1.13   cluster-timebertt-worker-1   <none>           <none>

NAME                   TYPE           CLUSTER-IP     EXTERNAL-IP                                    PORT(S)           AGE     SELECTOR
service/podinfo-prod   LoadBalancer   10.43.40.228   141.72.176.127,141.72.176.195,141.72.176.219   12001:31575/TCP   6m20s   app.kubernetes.io/name=podinfo-prod
```

Similar to the [Kustomize lab](kustomize.md#verify-the-deployments), we can verify the deployments by accessing the application on the external IP of the LoadBalancer service in the production environment or using `kubectl port-forward` in the development environment.

```bash
$ curl http://141.72.176.127:12001
{
  "hostname": "podinfo-prod-6475f96f98-mhcf9",
  "version": "6.9.0",
  "revision": "fb3b01be30a3f353b221365cd3b4f9484a0885ea",
  "color": "#34577c",
  "logo": "https://raw.githubusercontent.com/stefanprodan/podinfo/gh-pages/cuddle_clap.gif",
  "message": "Hello, Platform Engineering!",
  "goos": "linux",
  "goarch": "amd64",
  "runtime": "go1.24.3",
  "num_goroutine": "7",
  "num_cpu": "8"
}

$ kubectl -n podinfo-helm-dev port-forward svc/podinfo-dev 9898:9898

# in a new terminal
$ curl http://localhost:9898
{
  "hostname": "podinfo-dev-77bf97cf75-jms7z",
  "version": "6.9.2",
  "revision": "e86405a8674ecab990d0a389824c7ebbd82973b5",
  "color": "#34577c",
  "logo": "https://raw.githubusercontent.com/stefanprodan/podinfo/gh-pages/cuddle_clap.gif",
  "message": "Hello, Platform Engineering!",
  "goos": "linux",
  "goarch": "amd64",
  "runtime": "go1.25.1",
  "num_goroutine": "8",
  "num_cpu": "8"
}
```

Verify the log level configuration:

```bash
$ kubectl -n podinfo-helm-dev logs -l app.kubernetes.io/name=podinfo-dev
{"level":"info","ts":"2025-11-05T21:00:31.219Z","caller":"http/server.go:224","msg":"Starting HTTP Server.","addr":":9898"}
{"level":"debug","ts":"2025-11-05T21:00:33.272Z","caller":"http/logging.go:35","msg":"request started","proto":"HTTP/1.1","uri":"/readyz","method":"GET","remote":"[::1]:54936","user-agent":"Go-http-client/1.1"}
{"level":"debug","ts":"2025-11-05T21:00:42.050Z","caller":"http/logging.go:35","msg":"request started","proto":"HTTP/1.1","uri":"/healthz","method":"GET","remote":"[::1]:38484","user-agent":"Go-http-client/1.1"}

$ kubectl -n podinfo-helm-prod logs -l app.kubernetes.io/name=podinfo-prod
{"level":"info","ts":"2025-11-05T20:47:21.964Z","caller":"podinfo/main.go:153","msg":"Starting podinfo","version":"6.9.0","revision":"fb3b01be30a3f353b221365cd3b4f9484a0885ea","port":"9898"}
{"level":"info","ts":"2025-11-05T20:47:21.965Z","caller":"http/server.go:224","msg":"Starting HTTP Server.","addr":":9898"}
```
