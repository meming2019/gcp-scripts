#!/bin/bash

# End-to-end demo of a blue/green deployment using Cloud Run
# Based on gcloud CLI commands that are equivalent of the original demo steps in https://medium.com/@karthikg_54738/blue-green-deployment-google-cloud-run-927993d942c6

echo "######"
echo "###### Preparing env... ###################################"
echo "######"

echo "## Set base env variables..."
export MY_PROJECT='mz-df-demo-1'
export MY_REGION='us-central1'
export MY_ART_REPO='cats-app-repo3'
export MY_SERVICE='cat-service3'
export MY_REPO_HOST=${MY_REGION}-docker.pkg.dev

gcloud config set project ${MY_PROJECT}

echo "## Enable Artifact Registry..."
gcloud services enable artifactregistry.googleapis.com
echo "## Enable Cloud Run..."
gcloud services enable run.googleapis.com

export MY_IMAGE_BLUE='cat-service-blue'
export MY_IMAGE_URL_BLUE=${MY_REPO_HOST}/${MY_PROJECT}/${MY_ART_REPO}/${MY_SERVICE}:blue
echo "## Sample MY_IMAGE_URL_BLUE: us-central1-docker.pkg.dev/mz-df-demo-1/cats-app-repo/cat-service:blue"
echo "## Current MY_IMAGE_URL_BLUE is \"${MY_IMAGE_URL_BLUE}\""

export MY_IMAGE_GREEN='cat-service-green'
export MY_IMAGE_URL_GREEN=${MY_REPO_HOST}/${MY_PROJECT}/${MY_ART_REPO}/${MY_SERVICE}:green
echo "## Sample MY_IMAGE_URL_GREEN: us-central1-docker.pkg.dev/mz-df-demo-1/cats-app-repo/cat-service:green"
echo "## Current MY_IMAGE_URL_GREEN is \"${MY_IMAGE_URL_GREEN}\""

echo "## Create artifact repo ${MY_ART_REPO}..."
gcloud artifacts repositories create ${MY_ART_REPO} --repository-format=Docker --location=${MY_REGION}

echo "## Clone code..."
git clone https://github.com/guttapudi/node-cats.git
cd node-cats

echo "## Set the code back to the 'blue' version first..."
sed -i -e "s/version': '[a-z][a-z]*'/version': 'blue'/g" index.js

echo "######"
echo "###### Build and Deploy "blue" app... ###################################"
echo "######"

echo "### Build local docker image - blue ..."
docker build -t ${MY_IMAGE_BLUE} .
echo "## To test the image locally: "
echo "    docker run --publish 8080:8080 ${MY_IMAGE_BLUE}"
echo "    curl http://localhost:8080/cat"

echo "## Tag and Push (Linux/amd64) image \"${MY_IMAGE_BLUE}\" to artifactory url \"${MY_IMAGE_URL_BLUE}\"..."
# (For "exec format error", see https://cloud.google.com/run/docs/troubleshooting#container-failed-to-start)
docker tag ${MY_IMAGE_BLUE} ${MY_IMAGE_URL_BLUE}
#docker push ${MY_IMAGE_URL_BLUE}
docker buildx build --platform 'linux/amd64' --push -t${MY_IMAGE_URL_BLUE} .

echo "## See images/digests at https://console.cloud.google.com/artifacts/docker/${MY_PROJECT}/${MY_REGION}/${MY_ART_REPO}/${MY_SERVICE}?project=${MY_PROJECT}"

echo "## Deploy & run \"${MY_IMAGE_URL_BLUE}\" in Cluod Run as \"${MY_SERVICE}\"..."
gcloud run deploy ${MY_SERVICE} --image=${MY_IMAGE_URL_BLUE} --tag=blue --region=${MY_REGION} --allow-unauthenticated  --port=5050

MY_ENDPOINT=`gcloud run services describe ${MY_SERVICE} --region=${MY_REGION} --format='value(status.url)'`
echo "## Test app endpoint: ${MY_ENDPOINT}"
curl ${MY_ENDPOINT}/cat

echo "######"
echo "###### Build and Deploy "green" app... ###################################"
echo "######"

echo "### Change the code to the 'green' version for B/G deployment..."
sed -i -e "s/version': '[a-z][a-z]*'/version': 'green'/g" index.js

echo "## Build local docker image ..."
docker build -t ${MY_IMAGE_GREEN} .
echo "## To test the image locally: "
echo "    docker run --publish 8080:8080 ${MY_IMAGE_GREEN}"
echo "    curl http://localhost:8080/cat"

echo "## Tag and Push (Linux/amd64) image \"${MY_IMAGE_GREEN}\" to artifactory url \"${MY_IMAGE_URL_GREEN}\"..."
# (For "exec format error", see https://cloud.google.com/run/docs/troubleshooting#container-failed-to-start)
docker tag ${MY_IMAGE_GREEN} ${MY_IMAGE_URL_GREEN}
#docker push ${MY_IMAGE_URL_GREEN}
docker buildx build --platform 'linux/amd64' --push -t${MY_IMAGE_URL_GREEN} .

echo "## Deploy but NOT run \"${MY_IMAGE_URL_GREEN}\" in Cluod Run as \"${MY_SERVICE}\"..."
gcloud run deploy ${MY_SERVICE} --image=${MY_IMAGE_URL_GREEN} --tag=green --region=${MY_REGION} --allow-unauthenticated  --port=5050 --no-traffic

echo "######"
echo "###### Verify the new 'green' version before switching all traffic to it... ###################################"
echo "######"

MY_ENDPOINT=`gcloud run services describe ${MY_SERVICE} --region=${MY_REGION} --format='value(status.url)'`
echo "## Test app endpoint (100/0 'blue'/'green'): ${MY_ENDPOINT}"
for i in {1..10}; do curl ${MY_ENDPOINT}/cat && echo ; done

echo "## See traffic % distribution at https://console.cloud.google.com/run/detail/${MY_REGION}/${MY_SERVICE}/revisions?project=${MY_PROJECT}&supportedpurview=project"

echo "## Test 'green' by updating traffic flow to 50% to 'green' "
gcloud run services update-traffic ${MY_SERVICE} --to-tags green=50 --region=${MY_REGION}

echo "## Test app endpoint (50/50 'blue'/'green'): ${MY_ENDPOINT}"
for i in {1..10}; do curl ${MY_ENDPOINT}/cat && echo ; done

echo "## If 'green' appears fine, update traffic flow to 100% to 'green' "
gcloud run services update-traffic ${MY_SERVICE} --to-tags green=100 --region=${MY_REGION}

echo "## Test app endpoint (0/100 'blue'/'green'): ${MY_ENDPOINT}"
for i in {1..10}; do curl ${MY_ENDPOINT}/cat && echo ; done

