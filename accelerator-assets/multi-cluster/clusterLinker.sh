#!/bin/bash


#! ACCELERATOR SERVER-SIDE CREATED
#! CLUSTERLIST.CSV
#!
#! SCRIPT WALKS CSV AND CREATES ENCRICHED JSON FILE (with cluster urls and access tokens)
#! CLUSTERS.JSON
#!
#! SCRIPT USES YTT TO GENERATE CONFIGURATION FRAGMENT FOR TAP-GUI BLOCK OF TAP-VALUES (SENSITIVE) EMBEDDING CLUSTERS.JSON CONTENT
#!
#! TODO - take output yaml fragment and embed into tap-sensitive-values, reencrypt and update version deployed to git repo





mv clustersData.json clustersData.json.old 


echo "{\"CLUSTERS\":[" >> clustersData.json
while IFS=, read -r tapClusterName tapClusterContext; do
if [[ "$tapClusterName" != "# CLUSTER_LIST" ]]
  then
    echo "Fetching URL and ServiceAccount Token for Cluster Name $tapClusterName on context $tapClusterContext";
    kubectl config use-context $tapClusterContext
    CLUSTER_URL=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
    CLUSTER_TOKEN=$(kubectl -n tap-gui get secret tap-gui-viewer -o=json | jq -r '.data["token"]' | base64 --decode)
    echo 
    echo "Cluster $tapClusterName"
    echo "Context $tapClusterContext"
    echo "URL = $CLUSTER_URL"
    echo "TOKEN = $CLUSTER_TOKEN"
    echo 
    echo "{" >> clustersData.json
        echo "\"url\":\"$CLUSTER_URL\"," >> clustersData.json
        echo "\"name\":\"$tapClusterName\"," >> clustersData.json
        echo "\"authProvider\":\"serviceAccount\"," >> clustersData.json
        echo "\"serviceAccountToken\":\"$CLUSTER_TOKEN\"," >> clustersData.json
        echo "\"skipTLSVerify\":\"true\"," >> clustersData.json
        echo "\"skipMetricsLookup\":\"true\"" >> clustersData.json
    echo "}," >> clustersData.json
  fi 
done < ./clusterList.csv
cat clustersData.json | sed '$d' > clustersData-tmp.json
mv clustersData-tmp.json clustersData.json
echo "}" >> clustersData.json	
echo "]}" >> clustersData.json

export SOPS_AGE_RECIPIENTS=$(cat ../../key.txt | grep "# public key: " | sed 's/# public key: //')
export SOPS_AGE_KEY=$(cat ../../key.txt)
sops -d ../../clusters/taplab/cluster-config/values/tap-sensitive-values.sops.yaml > tap-sensitive-values-decrypted.yaml

ytt -f mc.yaml --data-value-file clusters=clustersData.json -f ./tap-sensitive-values-decrypted.yaml > ./tap-sensitive-values-decrypted-updated.yaml

sops -e tap-sensitive-values-decrypted-updated.yaml > ../../clusters/taplab/cluster-config/values/tap-sensitive-values.sops.yaml 
rm tap-sensitive-values-decrypted.yaml
rm tap-sensitive-values-decrypted-updated.yaml
rm clustersData.json


echo "UPDATING TAP-SENSITIVE-VALUES with MULTI-CLUSTER CONFIGURATION - VALIDATE BEFORE COMMITTING TO GIT-REPO"
