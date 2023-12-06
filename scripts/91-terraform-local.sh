source /usr/local/bin/.venv/bin/activate

# ModuleNotFoundError: No module named '_lzma'
apt -y install liblzma-dev
pip install backports.lzma
nano /usr/local/lib/python3.9/lzma.py
### Before modification
# from _lzma import *
# from _lzma import _encode_filter_properties, _decode_filter_properties

### After modification
# try:
#     from _lzma import *
#     from _lzma import _encode_filter_properties, _decode_filter_properties
# except ImportError:
#     from backports.lzma import *
#     from backports.lzma import _encode_filter_properties, _decode_filter_properties

# Download datasets
python -m fltk extractor configs/example_cloud_experiment.json
rm -rf ./data/*.tar.gz
rm -rf ./data/FashionMNIST/raw/*.gz
rm -rf ./data/MNIST/raw/*.gz

PROJECT_DIR="/home/engineer/fltk-testbed"
TERRAFORM_DEPENDENCIES_DIR="${PROJECT_DIR}/terraform/terraform-dependencies-local"

PROJECT_ID="test-bed-fltk" # Change PROJECT_ID if needed
DOMAIN="grc.io"
IMAGE='fltk'
IMAGE_NAME="${DOMAIN}/${PROJECT_ID}/${IMAGE}:latest"

# Start the cluster
minikube start --cpus 6 --memory 10240
# e.g.  NAMESPACE     NAME
#       kube-system   coredns-5d78c9869d-8b78w
#       kube-system   etcd-minikube
#       kube-system   kube-apiserver-minikube
#       kube-system   kube-controller-manager-minikube
#       kube-system   kube-proxy-67qdj
#       kube-system   kube-scheduler-minikube
#       kube-system   storage-provisioner

# Activate docker environment
eval $(minikube docker-env)

# Only run this command once during the setup
terraform -chdir=$TERRAFORM_DEPENDENCIES_DIR init -reconfigure

# Perform a dry-run
terraform -chdir=$TERRAFORM_DEPENDENCIES_DIR plan

# Install all dependencies
terraform -chdir=$TERRAFORM_DEPENDENCIES_DIR apply -auto-approve
# e.g.  NAMESPACE         NAME
#       kubeflow          training-operator-78fd847449-rpjjc
#       test              nfs-server-nfs-server-provisioner-0
#       volcano-system    volcano-admission-7fbf6567df-zr269
#       volcano-system    volcano-admission-init-29zxj
#       volcano-system    volcano-controllers-5864f67444-4qht2
#       volcano-system    volcano-scheduler-86bfcb65dd-tgg6w

# Build the docker container with buildkit
docker build --platform linux/amd64 ./ --tag gcr.io/test-bed-fltk/fltk
# In case you have issues with the command above, in a seperate terminal run
# DOCKER_BUILDKIT=1 docker build \
#    --platform linux/amd64 <fltk-directory> \
#    --tag gcr.io/test-bed-fltk/fltk
# minikube image load gcr.io/test-bed-fltk/fltk

# Deploy extractor (--set overwrites values from "fltk-values.yaml")
helm install extractor ./charts/extractor \
    -f ./charts/fltk-values.yaml \
    --namespace test \
    --set provider.projectName="${PROJECT_ID}",fltk.pullPolicy=Never
# e.g.  NAMESPACE NAME
#       test      fl-extractor-7c9bf8c6bb-t7zmt

# Port forward Tensorboard
EXTRACTOR_POD_NAME=$(kubectl get pods -n test -l "app.kubernetes.io/name=fltk.extractor" -o jsonpath="{.items[0].metadata.name}")
kubectl -n test port-forward $EXTRACTOR_POD_NAME 6006:6006


# Run deployment
ORCHESTRATOR_EXPERIMENT=$PROJECT_DIR/configs/distributed_tasks/qpec_arrival_config.json
ORCHESTRATOR_CONFIGURATION=$PROJECT_DIR/configs/qpec_cloud_experiment.json

helm install flearner ./charts/orchestrator \
    --namespace test -f charts/fltk-values.yaml \
    --set-file orchestrator.experiment=$ORCHESTRATOR_EXPERIMENT,orchestrator.configuration=$ORCHESTRATOR_CONFIGURATION \
    --set fltk.pullPolicy=Never,provider.projectID="${PROJECT_ID}"
# e.g.  NAMESPACE NAME
#       test      fl-server

# Download data from the extractor
cd $PROJECT_DIR
mkdir logging
kubectl cp -n test $EXTRACTOR_POD_NAME:/opt/federation-lab/logging ./logging

# Uninstall extractor
helm uninstall -n test extractor

minikube stop

# minikube delete
