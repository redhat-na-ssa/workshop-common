# @@TITLE@@ @@TAG@@ in a disconnected cluster

This bundle runs the workshop on a cluster with no internet access.
The site, its PDF, the Helm chart and the tools the exercises use all come from the
release, so nothing is downloaded during the workshop.

## What the release contains

The site's Downloads page lists the same files, and a site deployed from the
`@@IMAGE@@:@@TAG@@` image serves them under `/release-files/`.

| File or image | What it is |
| --- | --- |
| `@@NAME@@-offline-@@TAG@@.tar.gz` | This file, `TOOLS.md`, the built site (`www/`, with a Helm chart repository in `www/helm/` and these files in `www/release-files/`), the chart, the PDF, `tools-deployment.yaml` and `images-mirror.txt` |
| `DISCONNECTED.md`, `TOOLS.md`, `tools-deployment.yaml`, `images-mirror.txt` | This guide, the tools image guide, the tools pod on its own and the images to mirror |
| `@@NAME@@-@@TAG@@.pdf` | The whole workshop as one PDF |
| `@@NAME@@-@@VERSION@@.tgz` | The Helm chart: the site, and a pod with the tools |
| `@@IMAGE@@:@@TAG@@` | The site, served over HTTP on port 8080 |
| `@@IMAGE@@-tools:@@TAG@@` | The command-line tools the exercises use (see `TOOLS.md`) |
| `*.sbom.cdx.json` | CycloneDX SBOMs of the two images |

## 1. Mirror the images

From a host that can reach both registries, copy each image in `images-mirror.txt` to
your registry, for example:

```bash
oc image mirror \
  @@IMAGE@@:@@TAG@@ \
  registry.example.com/workshop/@@NAME@@:@@TAG@@
```

```bash
oc image mirror \
  @@IMAGE@@-tools:@@TAG@@ \
  registry.example.com/workshop/@@NAME@@-tools:@@TAG@@
```

Images the exercises themselves pull are listed on each workshop's Setup Requirements page;
mirror those too.

## 2. Install the chart

Create the project first, then install into it:

```bash
oc new-project workshop
```

```bash
helm upgrade --install workshop ./@@NAME@@-@@VERSION@@.tgz \
  --namespace workshop \
  --set image.repository=registry.example.com/workshop/@@NAME@@ \
  --set image.tag=@@TAG@@ \
  --set tools.image.repository=registry.example.com/workshop/@@NAME@@-tools \
  --set tools.image.tag=@@TAG@@
```

Set `route.enabled=false` off OpenShift, and `tools.enabled=false` to skip the tools pod.
The chart's notes print the site's address.

Once the site runs, its `/helm/` path is also a Helm chart repository:

```bash
helm repo add @@NAME@@ https://<site-host>/helm/
```

## 3. Without Helm

Any web server can serve `www/` from the bundle as it is.
For the tools pod alone, import `tools-deployment.yaml` in the web console (see `TOOLS.md`).
