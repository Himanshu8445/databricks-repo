#!/bin/bash

# TO DO
# You might want to Pin your clusters

# Must be run in the directory with the clusters (spaces in names in Bash can cause issues)
accessToken=$1
workspaceUrl=$2

######################################################################################
# Deploy clusters (Add or Update existing)
######################################################################################

replaceSource="./"
replaceDest=""

# Get a list of clusters so we know if we need to create or edit
clusterList=$(curl -vvv GET $workspaceUrl/api/2.0/clusters/list \
            -H "Authorization:Bearer $accessToken" \
            -H "Content-Type: application/json")

echo clusterList
find . -type f -name "*" -print0 | while IFS= read -r -d '' file; do

    echo "Processing file: $file"
    filename=${file//$replaceSource/$replaceDest}
    echo "New filename: $filename"


    clusterName=$(cat $filename | jq -r .cluster_name)
    clusterId=$(echo $clusterList | jq -r ".clusters[] | select(.cluster_name == \"$clusterName\") | .cluster_id")

    echo "clusterName: $clusterName"
    echo "clusterId: $clusterId"

    # Test for empty cluster id (meaning it does not exist)
    if [ -z "$clusterId" ];
    then
       echo "Cluster $clusterName does not exists in Databricks workspace, Creating..."
       echo "curl $workspaceUrl/api/2.0/clusters/create -d $filename"

       curl -vvv POST $workspaceUrl/api/2.0/clusters/create \
            -H "Authorization:Bearer $accessToken" \
            -H "Content-Type: application/json" \
            -d @"$filename" 

    else
       echo "Cluster $clusterName exists in Databricks workspace, Updating..."
       echo "curl $workspaceUrl/api/2.0/clusters/edit -d $filename"

       # need to inject some JSON into the file for updating existing cluster
       clusterDef=$(cat $filename)

       newJSON=$(echo $clusterDef | jq ". += {cluster_id: \"$clusterId\"}")
       echo "New Cluster Def"
       echo $newJSON
       echo ""

       curl -vvv POST $workspaceUrl/api/2.0/clusters/edit \
            -H "Authorization:Bearer $accessToken" \
            -H "Content-Type: application/json" \
            --data "$newJSON"

    fi      
    echo ""  

done


######################################################################################
# Sleep will the above calls complete
######################################################################################
read -p "sleeping" -t 15


######################################################################################
# Stop the clusters
######################################################################################

# Get a list of clusters so we know if we need to create or edit
clusterList=$(curl -vvv GET $workspaceUrl/api/2.0/clusters/list \
               -H "Authorization:Bearer $accessToken" \
               -H "Content-Type: application/json")

find . -type f -name "*" -print0 | while IFS= read -r -d '' file; do
    echo "Processing file: $file"
    filename=${file//$replaceSource/$replaceDest}
    echo "New filename: $filename"

    clusterName=$(cat $filename | jq -r .cluster_name)
    clusterId=$(echo $clusterList | jq -r ".clusters[] | select(.cluster_name == \"$clusterName\") | .cluster_id")

    echo "clusterName: $clusterName"
    echo "clusterId: $clusterId"

    # Test for empty cluster id (meaning it does not exist)
    if [ -z "$clusterId" ];
    then
       echo "WARNING: Cluster $clusterName did not have a Cluster Id.  Stopping the cluster will not occur."

    else
       echo "Cluster $clusterName with Cluster ID $clusterId, Stopping..."
       echo "curl $workspaceUrl/api/2.0/clusters/delete -d $clusterId"

       newJSON="{ \"cluster_id\" : \"$clusterId\" }"
       echo "Cluster to stop: $newJSON"
   
       # NOTE: permanent-delete is used to "delete" the cluster.  Delete below means "stop" the clustter
       curl -vvv POST $workspaceUrl/api/2.0/clusters/delete \
            -H "Authorization:Bearer $accessToken" \
            -H "Content-Type: application/json" \
            --data "$newJSON"
    fi     
    echo ""  

done
