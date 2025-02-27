#!/usr/bin/env bash

# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

PRJ_ROOT="$(cd `dirname "${BASH_SOURCE}"`/../..; pwd)"
ENV_CODE=${1:-${ENV_CODE}}

if [[ -z "$1" ]]
  then
    echo "Environment Code value not supplied"
    exit 1
fi

set -a
ENV_NAME=${ENV_NAME:-"stac-${ENV_CODE}"}
MONITORING_RESOURCE_GROUP=${MONITORING_RESOURCE_GROUP:-"${ENV_CODE}-monitoring-rg"}
VNET_RESOURCE_GROUP=${VNET_RESOURCE_GROUP:-"${ENV_CODE}-vnet-rg"}
DATA_RESOURCE_GROUP=${DATA_RESOURCE_GROUP:-"${ENV_CODE}-data-rg"}
PROCESSING_RESOURCE_GROUP=${PROCESSING_RESOURCE_GROUP:-"${ENV_CODE}-processing-rg"}

SUBSCRIPTION=$(az account show --query id -o tsv)
AZURE_APP_INSIGHTS=$(az resource list -g $MONITORING_RESOURCE_GROUP --resource-type "Microsoft.Insights/components" \
    --query "[?tags.environment && tags.environment == '$ENV_NAME'].name" -o tsv)

AZURE_LOG_CONNECTION_STRING=$(az resource show \
    -g $MONITORING_RESOURCE_GROUP \
    --resource-type Microsoft.Insights/components \
    -n ${AZURE_APP_INSIGHTS} \
    --query "properties.ConnectionString" -o tsv)

DATA_STORAGE_ACCOUNT_NAME=$(az storage account list \
    --query "[?tags.store && tags.store == 'data'].name" -o tsv -g ${DATA_RESOURCE_GROUP})
DATA_STORAGE_ACCOUNT_KEY=$(az storage account keys list \
    --account-name ${DATA_STORAGE_ACCOUNT_NAME} --resource-group ${DATA_RESOURCE_GROUP} \
    --query "[0].value" -o tsv)
STORAGE_ACCOUNT_ENDPOINT_SUFFIX=$(az cloud show --query suffixes.storageEndpoint --output tsv) 

DATA_STORAGE_ACCOUNT_CONNECTION_STRING="DefaultEndpointsProtocol=https;EndpointSuffix=$STORAGE_ACCOUNT_ENDPOINT_SUFFIX;AccountName=$DATA_STORAGE_ACCOUNT_NAME;AccountKey=$DATA_STORAGE_ACCOUNT_KEY"

AKS_RESOURCE_GROUP=${AKS_RESOURCE_GROUP:-${PROCESSING_RESOURCE_GROUP}}
AKS_CLUSTER_NAME=$(az aks list -g ${PROCESSING_RESOURCE_GROUP} \
    --query "[?tags.type && tags.type == 'k8s'].name" -otsv)
ACR_DNS=$(az acr list -g ${PROCESSING_RESOURCE_GROUP} \
    --query "[?tags.environment && tags.environment == '$ENV_NAME'].loginServer" -otsv)
SERVICE_BUS_NAMESPACE=$(az servicebus namespace list \
    -g ${DATA_RESOURCE_GROUP} --query "[?tags.environment && tags.environment == '$ENV_NAME'].name" -otsv)

STAC_METADATA_TYPE_NAME=${STAC_METADATA_TYPE_NAME:-"fgdc"}
COLLECTION_ID=${COLLECTION_ID:-"naip"}
JPG_EXTENSION=${JPG_EXTENSION:-"200.jpg"}
XML_EXTENSION=${XML_EXTENSION:-"aux.xml"}
REPLICAS=${REPLICAS:-"3"}
POD_CPU=${POD_CPU:-"0.5"}
POD_MEMORY=${POD_MEMORY:-"2Gi"}

GENERATE_STAC_JSON_IMAGE_NAME=${GENERATE_STAC_JSON_IMAGE_NAME:-"generate-stac-json"}
DATA_STORAGE_PGSTAC_CONTAINER_NAME=${DATA_STORAGE_PGSTAC_CONTAINER_NAME:-"pgstac"}
ENV_LABLE=${ENV_LABLE:-"stacpool"} # aks agent pool name to deploy kubectl deployment yaml files

STAC_EVENT_CONSUMER_IMAGE_NAME=${STAC_EVENT_CONSUMER_IMAGE_NAME:-"stac-event-consumer"}
PGSTAC_SERVICE_BUS_TOPIC_NAME=${PGSTAC_SERVICE_BUS_TOPIC_NAME:-"pgstactopic"}
PGSTAC_SERVICE_BUS_TOPIC_AUTH_POLICY_NAME=${PGSTAC_SERVICE_BUS_TOPIC_AUTH_POLICY_NAME:-"pgstacpolicy"}
PGSTAC_SERVICE_BUS_SUBSCRIPTION_NAME=${PGSTAC_SERVICE_BUS_SUBSCRIPTION_NAME:-"pgstacsubscription"}
PGSTAC_SERVICE_BUS_CONNECTION_STRING=$(az servicebus topic authorization-rule keys list \
    --resource-group ${DATA_RESOURCE_GROUP} \
    --namespace-name ${SERVICE_BUS_NAMESPACE} \
    --topic ${PGSTAC_SERVICE_BUS_TOPIC_NAME} \
    --name ${PGSTAC_SERVICE_BUS_TOPIC_AUTH_POLICY_NAME} \
    --query "primaryConnectionString" -otsv)

GENERATED_STAC_STORAGE_CONTAINER_NAME=${GENERATED_STAC_STORAGE_CONTAINER_NAME:-"generatedstacjson"}

KEY_VAULT_NAME=$(az keyvault list --query "[?tags.environment && tags.environment == '$ENV_NAME'].name" -o tsv -g $DATA_RESOURCE_GROUP)
PGHOST=$(az postgres flexible-server list --resource-group $DATA_RESOURCE_GROUP --query '[].fullyQualifiedDomainName' -o tsv)
PGHOSTONLY=$(az postgres flexible-server list --resource-group $DATA_RESOURCE_GROUP --query '[].name' -o tsv)
PGUSER=$(az postgres flexible-server list --resource-group $DATA_RESOURCE_GROUP --query '[].administratorLogin' -o tsv)
PGPASSWORD_SECRET_NAME=${PGPASSWORD_SECRET_NAME:-"PGAdminLoginPass"}
PGPASSWORD=$(az keyvault secret show --vault-name $KEY_VAULT_NAME --name $PGPASSWORD_SECRET_NAME --query value -o tsv)
PGDATABASE=${PGDATABASE:-"postgres"}
PGPORT=${PGPORT:-"5432"}

STACIFY_STORAGE_CONTAINER_NAME=${STACIFY_STORAGE_CONTAINER_NAME:-"stacify"}
STACIFY_SERVICE_BUS_TOPIC_NAME=${STACIFY_SERVICE_BUS_TOPIC_NAME:-"stacifytopic"}
STACIFY_SERVICE_BUS_TOPIC_AUTH_POLICY_NAME=${STACIFY_SERVICE_BUS_TOPIC_AUTH_POLICY_NAME:-"stacifypolicy"}
STACIFY_SERVICE_BUS_SUBSCRIPTION_NAME=${STACIFY_SERVICE_BUS_SUBSCRIPTION_NAME:-"stacifysubscription"}
STACIFY_SERVICE_BUS_CONNECTION_STRING=$(az servicebus topic authorization-rule keys list \
    --resource-group ${DATA_RESOURCE_GROUP} \
    --namespace-name ${SERVICE_BUS_NAMESPACE} \
    --topic ${STACIFY_SERVICE_BUS_TOPIC_NAME} \
    --name ${STACIFY_SERVICE_BUS_TOPIC_AUTH_POLICY_NAME} \
    --query "primaryConnectionString" -otsv)

STAC_COLLECTION_IMAGE_NAME=${STAC_COLLECTION_IMAGE_NAME:-"stac-collection"}
STACCOLLECTION_STORAGE_CONTAINER_NAME=${STACCOLLECTION_STORAGE_CONTAINER_NAME:-"staccollection"}
STACCOLLECTION_SERVICE_BUS_TOPIC_NAME=${STACCOLLECTION_SERVICE_BUS_TOPIC_NAME:-"staccollectiontopic"}
STACCOLLECTION_SERVICE_BUS_AUTH_POLICY_NAME=${STACCOLLECTION_SERVICE_BUS_AUTH_POLICY_NAME:-"staccollectionpolicy"}
STACCOLLECTION_SERVICE_BUS_SUBSCRIPTION_NAME=${STACCOLLEcTION_SERVICE_BUS_SUBSCRIPTION_NAME:-"staccollectionsubscription"}
STACCOLLECTION_SERVICE_BUS_CONNECTION_STRING=$(az servicebus topic authorization-rule keys list \
    --resource-group ${DATA_RESOURCE_GROUP} \
    --namespace-name ${SERVICE_BUS_NAMESPACE} \
    --topic ${STACCOLLECTION_SERVICE_BUS_TOPIC_NAME} \
    --name ${STACCOLLECTION_SERVICE_BUS_AUTH_POLICY_NAME} \
    --query "primaryConnectionString" -otsv)

AKS_NAMESPACE=${AKS_NAMESPACE:-"pgstac"}
ENV_LABEL=${ENV_LABEL:-"stacpool"} # aks agent pool name to deploy kubectl deployment yaml files
set +a
export -p

echo 'enabling POSTGIS,BTREE_GIST in postgres'
az postgres flexible-server \
    parameter set \
    --resource-group $DATA_RESOURCE_GROUP --server-name $PGHOSTONLY \
    --subscription $SUBSCRIPTION --name azure.extensions --value POSTGIS,BTREE_GIST

az aks get-credentials --resource-group ${AKS_RESOURCE_GROUP} --name ${AKS_CLUSTER_NAME} --context ${AKS_CLUSTER_NAME} --overwrite-existing
kubectl config set-context ${AKS_CLUSTER_NAME}

echo "creating $AKS_NAMESPACE namespace"
envsubst < "${PRJ_ROOT}/deploy/kube_yaml/namespace.yaml" | kubectl apply -f -

echo "deploying stacfastapi"
envsubst < ${PRJ_ROOT}/src/stac_fastapi_k8s/app-stacfastapi-deployment.tpl.yaml | kubectl -n $AKS_NAMESPACE apply -f -

echo "deploying aks-ingest"
envsubst < ${PRJ_ROOT}/src/stac_ingestion/aks-ingest-deployment.yaml | kubectl -n $AKS_NAMESPACE apply -f -