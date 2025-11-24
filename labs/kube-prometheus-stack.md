# Lab: Kube-Prometheus-Stack

[Task Description](https://talks.timebertt.dev/platform-engineering/#/lab-kube-prometheus-stack)

## Install the Kube-Prometheus-Stack Helm Chart

We install the [Kube-Prometheus-Stack helm chart](https://artifacthub.io/packages/helm/prometheus-community/kube-prometheus-stack) via a Flux `HelmRelease` in the [`clusters/dhbw/kube-prometheus-stack.yaml`](../clusters/dhbw/kube-prometheus-stack.yaml) file.
For this, we create a `HelmRepository` of type `oci` pointing to `oci://ghcr.io/prometheus-community/charts`.

We then create a `HelmRelease` that deploys the chart from this repository in the `monitoring` namespace.

In the values of the `HelmRelease`, we customize the Grafana and Prometheus configurations.
The `kube-prometheus-stack` helm chart uses the [official Grafana chart](https://artifacthub.io/packages/helm/grafana/grafana) as a dependency and thus exposes the same configuration options for the Grafana deployment.
All values under the `grafana` section are passed to the Grafana subchart.

## Enable Persistent Storage

For enabling persistent storage in Grafana, we switch from a Deployment to a StatefulSet as this simplifies rollouts when persistent storage is enabled.
Using a Deployment would require us to use the `Replace` rollout strategy as a rolling update would get stuck because a `PersistentVolume` can only be mounted to a single pod at a time.
With persistent storage enabled for Grafana, all dashboards created in the Grafana UI are stored persistently and survive pod restarts and upgrades.

```yaml
grafana:
  # Switch from a Deployment to a StatefulSet for Grafana.
  # This simplifies things when enabling persistent storage.
  useStatefulSet: true

  # Enable persistent storage for Grafana.
  # This enables us to simply create and manage dashboards in the UI without the detour via ConfigMaps.
  persistence:
    enabled: true
```

For Prometheus, we enable persistent storage by configuring a `volumeClaimTemplate` under `prometheus.prometheusSpec.storageSpec`.
This is passed to the `Prometheus` object created by the helm chart.
The prometheus-operator will then create a `StatefulSet` for this `Prometheus` object with the specified persistent storage.
Furthermore, we configure a size-based retention policy for Prometheus, meaning that metrics data is retained until the persistent storage is full.
When more metrics data is collected, older data will be deleted to make space for new data.

```yaml
prometheus:
  # Customize the Prometheus object created by the helm chart.
  prometheusSpec:
    # Enable persistent storage for Prometheus.
    # This is important to retain metrics data across pod restarts and upgrades.
    storageSpec:
      volumeClaimTemplate:
        spec:
          resources:
            requests:
              storage: 20Gi

    # Retain metrics data until the persistent storage is full.
    # When more metrics data is collected, older data will be deleted to make space for new data.
    retentionSize: 20GiB
```

## Expose Grafana and Prometheus via Ingress

To expose Grafana and Prometheus via an Ingress, we enable the ingress configuration for both components by setting the `ingress.enabled` value to `true` in the respective sections.
We specify the hostnames for the Ingress resources, enable TLS (HTTPS) for those hosts, and add cert-manager annotations to automatically manage trusted TLS certificates via Let's Encrypt.

```yaml
grafana:
  ingress:
    # Enable ingress for Grafana
    enabled: true
    # Explicitly select the ingress-nginx controller in case the IngressClass has not been set as default
    ingressClassName: nginx

    # Define the host for Grafana ingress
    # <sub-domain>.<cluster-name>.dski23a.timebertt.dev
    hosts:
    - &host grafana.timebertt.dski23a.timebertt.dev
    tls:
    - secretName: grafana-tls
      hosts:
      - *host

    # Enable cert-manager annotations for automatic TLS certificate management
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt

prometheus:
  ingress:
    # Enable ingress for Prometheus
    enabled: true
    # Explicitly select the ingress-nginx controller in case the IngressClass has not been set as default
    ingressClassName: nginx

    # Define the host for Prometheus ingress
    # <sub-domain>.<cluster-name>.dski23a.timebertt.dev
    hosts:
    - &host prometheus.timebertt.dski23a.timebertt.dev
    tls:
    - secretName: prometheus-tls
      hosts:
      - *host

    # Enable cert-manager annotations for automatic TLS certificate management
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt
```

After applying the `HelmRelease` with the above configuration, Flux will create the respective Ingress resources for Grafana and Prometheus.
Based on this, external-dns will automatically create the required DNS records, and cert-manager will request TLS certificates from Let's Encrypt for secure HTTPS access.
Note that it may take a few minutes for cert-manager to issue the TLS certificates.
We can check the status of the certificate issuance by inspecting the `Certificate` and `CertificateRequest` resources in the `monitoring` namespace.

## Access Grafana

When accessing Grafana, we need to log in to view the dashboards and explore the metrics.
The helm chart generates a random password for the `admin` user and stores it in a Kubernetes `Secret` in the `monitoring` namespace.
We can retrieve the password using the following command:

```bash
$ kubectl -n monitoring get secret kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 --decode; echo
```

Copy the output of this command and use it to log in to Grafana with the username `admin`.

## Explore Pre-Configured Grafana Dashboards

The Kube-Prometheus-Stack helm chart comes with several pre-configured Grafana dashboards for monitoring the Kubernetes cluster and its components.
After logging in to Grafana, we can explore these dashboards by navigating to the "Dashboards" section in the Grafana UI.
One of the most useful dashboards is the "Kubernetes / Compute Resources / Cluster" dashboard, which provides an overview of the cluster's resource consumption, including CPU, memory, network, and IO usage across all nodes and namespaces.
