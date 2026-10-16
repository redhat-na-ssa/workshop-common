# @@TITLE@@ tools image

`@@IMAGE@@-tools:@@TAG@@` holds every command-line tool the exercises use, so attendees
need nothing installed on their own machine, not even `oc`.

It has `oc`, `kubectl`, `helm`, `jq`, `yq`, `git`, `gpg`, `curl`, `wget`, `skopeo` and a
`docker` shim, plus the tools this workshop adds. The banner in an interactive shell lists them.

## Start it

- With the Helm chart: it's on by default (`tools.enabled: true`).
- From the web console: choose your project, click **+** then **Import YAML**, paste
  `tools-deployment.yaml` from the bundle, change its `image:` line to your mirror, and click
  **Create**. Open **Workloads**, **Pods**, the pod, **Terminal**, and run `bash` if it starts `sh`.

## Use it

Commands in the pod act as the pod's ServiceAccount, which can't do anything yet.
Either log in as yourself inside the pod (web console: your user name, **Copy login command**),
or have a project admin grant the ServiceAccount the role the exercises need.

The workshop's Helm chart is in `~/chart`. To install the site from the pod, skip a second
tools pod:

```bash
helm upgrade --install workshop ~/chart \
  --namespace <your-project> \
  --set tools.enabled=false
```

## The docker shim

There's no container engine in the image. `docker` maps a few commands to `skopeo`:
`manifest inspect`, `pull` (to a local directory), `image inspect` and `history`.
