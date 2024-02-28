# Kubernetes Sandbox
## This repo allows you to practice with Kubernetes by creating a Sandobox for a developer.
This repo aims to make it easier to setup a Kind Cluster, ready to use localy with Ingress NGINX and a demo app.

With this, a Dev is able to start using Kubernetes, and to test localy their own applications.

## Usage:

run:

```bash

./sandbox.sh help

```

To see all the available commands.

### Install Kind Binaries (Mac/Linux):

```bash

./sandbox.sh installKind

```


### Create Cluster:

```bash

./sandbox.sh createCluster

```

### Delete Cluster:

```bash

./sandbox.sh deleteCluster

```

### Deploy Application:

Add contents to the box folder. 

```bash

./sandbox.sh box <app_name> <action>

```

Where action mean kubectl action like:

- apply
- delete

The structure of the app_name folder should be:

- folder name will be used as the namespace.
- inside the app name folder, create "manifests" folder.
- inside "manifests" folder you should create .yml files with the kubernetes manifests.

