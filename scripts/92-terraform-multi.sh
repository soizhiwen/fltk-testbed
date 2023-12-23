source /usr/local/bin/.venv/bin/activate

# Download datasets
python -m fltk extractor configs/example_cloud_experiment.json
rm -rf ./data/*.tar.gz
rm -rf ./data/FashionMNIST/raw/*.gz
rm -rf ./data/MNIST/raw/*.gz

PROJECT_DIR="/home/engineer/fltk-testbed"
TERRAFORM_DEPENDENCIES_DIR="${PROJECT_DIR}/terraform/terraform-dependencies-local"

PROJECT_ID="test-bed-fltk"
DOMAIN="grc.io"
IMAGE='fltk'
IMAGE_NAME="${DOMAIN}/${PROJECT_ID}/${IMAGE}:latest"

# Start the cluster with multiple nodes
minikube start --nodes 4 --cpus 4 --memory 8192 -p multinode

# Enable the registry addon (multiple nodes)
# minikube addons enable registry -p multinode

# Only run this command once during the setup
terraform -chdir=$TERRAFORM_DEPENDENCIES_DIR init -reconfigure

# Perform a dry-run
terraform -chdir=$TERRAFORM_DEPENDENCIES_DIR plan

# Install all dependencies
terraform -chdir=$TERRAFORM_DEPENDENCIES_DIR apply -auto-approve

# Load docker image to minikube
DOCKER_BUILDKIT=1 docker build \
   --platform linux/amd64 ./ \
   --tag gcr.io/test-bed-fltk/fltk
minikube image load gcr.io/test-bed-fltk/fltk -p multinode

# Deploy extractor (--set overwrites values from "fltk-values.yaml")
helm install extractor ./charts/extractor \
    -f ./charts/fltk-values.yaml \
    --namespace test \
    --set provider.projectName="${PROJECT_ID}",fltk.pullPolicy=Never

# Port forward Tensorboard
EXTRACTOR_POD_NAME=$(kubectl get pods -n test -l "app.kubernetes.io/name=fltk.extractor" -o jsonpath="{.items[0].metadata.name}")
kubectl -n test port-forward $EXTRACTOR_POD_NAME 6006:6006

# Run deployment
EXP_NAME=exp_23
ORCHESTRATOR_EXPERIMENT=$PROJECT_DIR/configs/distributed_tasks/$EXP_NAME.json
ORCHESTRATOR_CONFIGURATION=$PROJECT_DIR/configs/qpec_cloud_experiment.json

helm install flearner ./charts/orchestrator \
    --namespace test -f charts/fltk-values.yaml \
    --set-file orchestrator.experiment=$ORCHESTRATOR_EXPERIMENT,orchestrator.configuration=$ORCHESTRATOR_CONFIGURATION \
    --set fltk.pullPolicy=Never,provider.projectID="${PROJECT_ID}"

# Download data from the extractor
cd $PROJECT_DIR
mkdir logging
kubectl cp -n test $EXTRACTOR_POD_NAME:/opt/federation-lab/logging ./logging

# Get the configmaps of the experiment
kubectl describe configmaps -n test > ./logging/$EXP_NAME/configmaps.txt

# Save the orchestrator log
kubectl logs -n test fl-server > ./logging/$EXP_NAME/fl-server.log

# Save the train job log
kubectl get pods -n test --no-headers=true --field-selector=status.phase=Succeeded | \
awk '/^trainjob.*master.*$/{print $1}' | \
xargs -I {} sh -c 'kubectl logs -n test {} > ./logging/'$EXP_NAME'/{}.log'

# Uninstall extractor
helm uninstall -n test extractor

# Uninstall flearner
helm uninstall -n test flearner

# Delete completed pods
kubectl get pods -n test --no-headers=true --field-selector=status.phase=Succeeded | \
awk '/trainjob/{print $1}' | \
xargs kubectl delete -n test pod --force

minikube stop -p multinode

minikube delete -p multinode
