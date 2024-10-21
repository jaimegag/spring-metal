#!/usr/bin/env bash

APP_NAME="boneyard-assist" # overridable, necessary for TPK8s ingress route

PGVECTOR_SERVICE_NAME="boneyard-db"
PGVECTOR_PLAN_NAME="on-demand-postgres-db"

CHAT_SERVICE_NAME="boneyard-chat" 
CHAT_PLAN_NAME="chat-test-compute-constraint" # plan must have chat capabilty

EMBEDDINGS_SERVICE_NAME="boneyard-embeddings" 
EMBEDDINGS_PLAN_NAME="embeddings-test" # plan must have Embeddings capabilty

BASE_APP_NAME="spring-metal" #if you want to demo in two phases, no ai and then "adding" AI assist, this would be the app name prior to add the AI assist
BASE_APP_DB="music-db" #if you want to demo in two phases, no ai and then "adding" AI assist, this would be the app name prior to add the AI assist

#prepare k8s
prepare-k8s() {

    registry_folder=$1

    if [[ "$OSTYPE" == "darwin"* ]]; then
        SED_INPLACE_COMMAND="sed -i.bak"
    else
        SED_INPLACE_COMMAND="sed -i"
    fi
    
    
    
    echo && printf "\e[35m▶ Creating service keys for GenAI and Postgres \e[m\n" && echo

    cf create-service-key $PGVECTOR_SERVICE_NAME external-binding
    PGVECTOR_GUID=$(cf service-key $PGVECTOR_SERVICE_NAME external-binding --guid)
    PGVECTOR_SERVICE_JSON=$(cf curl "/v3/service_credential_bindings/$PGVECTOR_GUID/details") 
    PGVECTOR_HOST=$(echo -n $PGVECTOR_SERVICE_JSON | jq -r -c '.credentials.service_gateway.host' | base64)
    PGVECTOR_PORT=$(echo -n $PGVECTOR_SERVICE_JSON | jq -r -c '.credentials.service_gateway.port' | base64)
    PGVECTOR_USERNAME=$(echo -n $PGVECTOR_SERVICE_JSON | jq -r -c '.credentials.user' | base64)
    PGVECTOR_PASSWORD=$(echo -n $PGVECTOR_SERVICE_JSON | jq -r -c '.credentials.password'| base64)

    cf create-service-key $CHAT_SERVICE_NAME external-binding
    CHAT_GUID=$(cf service-key $CHAT_SERVICE_NAME external-binding --guid)
    CHAT_SERVICE_JSON=$(cf curl "/v3/service_credential_bindings/$CHAT_GUID/details") 
    CHAT_MODEL_CAPABILITIES=$(echo -n $CHAT_SERVICE_JSON | jq -r -c '.credentials.model_capabilities| @csv' | sed 's/\"//g'| base64)
    CHAT_MODEL_NAME=$(echo -n $CHAT_SERVICE_JSON | jq -r -c '.credentials.model_name'| base64)
    CHAT_API_URL=$(echo -n $CHAT_SERVICE_JSON | jq -r -c '.credentials.api_base'| base64)
    CHAT_API_KEY=$(echo -n $CHAT_SERVICE_JSON | jq -r -c '.credentials.api_key'| base64)

    cf create-service-key $EMBEDDINGS_SERVICE_NAME external-binding
    EMBED_GUID=$(cf service-key $EMBEDDINGS_SERVICE_NAME external-binding --guid)
    EMBED_SERVICE_JSON=$(cf curl "/v3/service_credential_bindings/$EMBED_GUID/details") 
    EMBED_MODEL_CAPABILITIES=$(echo -n $EMBED_SERVICE_JSON | jq -r -c '.credentials.model_capabilities| @csv' | sed 's/\"//g'| base64)
    EMBED_MODEL_NAME=$(echo -n $EMBED_SERVICE_JSON | jq -r -c '.credentials.model_name'| base64)
    EMBED_API_URL=$(echo -n $EMBED_SERVICE_JSON | jq -r -c '.credentials.api_base'| base64)
    EMBED_API_KEY=$(echo -n $EMBED_SERVICE_JSON | jq -r -c '.credentials.api_key'| base64)

    echo && printf "\e[35m▶ Copying and templating runtime-configs/tpk8s/tanzu-config to .tanzu and .tanzu/config \e[m\n" && echo

    rm -rf .tanzu/config
    mkdir -p .tanzu/config

    sed "s/APP_NAME/$APP_NAME/g" runtime-configs/tpk8s/tanzu-config/build-plan.yml > .tanzu//build-plan.yml
    $SED_INPLACE_COMMAND "s|IMG_REGISTRY|harbor.vmtanzu.com\/$registry_folder|" .tanzu//build-plan.yml
        
    sed "s/APP_NAME/$APP_NAME/g" runtime-configs/tpk8s/tanzu-config/spring-metal.yml > .tanzu/config/spring-metal.yml
    
    sed "s/APP_NAME/$APP_NAME/g" runtime-configs/tpk8s/tanzu-config/httproute.yml > .tanzu/config/httproute.yml
      
    sed "s/APP_NAME/$APP_NAME/" runtime-configs/tpk8s/tanzu-config/genai-external-service.yml > .tanzu/config/genai-external-service.yml
    $SED_INPLACE_COMMAND "s|CHAT_MODEL_CAPABILITIES|$CHAT_MODEL_CAPABILITIES|" .tanzu/config/genai-external-service.yml 
    $SED_INPLACE_COMMAND "s|CHAT_SERVICE_NAME|$CHAT_SERVICE_NAME|" .tanzu/config/genai-external-service.yml 
    $SED_INPLACE_COMMAND "s|CHAT_MODEL_NAME|$CHAT_MODEL_NAME|" .tanzu/config/genai-external-service.yml 
    $SED_INPLACE_COMMAND "s|CHAT_API_URL|$CHAT_API_URL|" .tanzu/config/genai-external-service.yml 
    $SED_INPLACE_COMMAND "s|CHAT_API_KEY|$CHAT_API_KEY|" .tanzu/config/genai-external-service.yml 
    $SED_INPLACE_COMMAND "s/EMBED_MODEL_CAPABILITIES/$EMBED_MODEL_CAPABILITIES/" .tanzu/config/genai-external-service.yml 
    $SED_INPLACE_COMMAND "s|EMBEDDINGS_SERVICE_NAME|$EMBEDDINGS_SERVICE_NAME|" .tanzu/config/genai-external-service.yml 
    $SED_INPLACE_COMMAND "s|EMBED_MODEL_NAME|$EMBED_MODEL_NAME|" .tanzu/config/genai-external-service.yml 
    $SED_INPLACE_COMMAND "s|EMBED_API_URL|$EMBED_API_URL|" .tanzu/config/genai-external-service.yml 
    $SED_INPLACE_COMMAND "s|EMBED_API_KEY|$EMBED_API_KEY|" .tanzu/config/genai-external-service.yml 

    
    sed "s/APP_NAME/$APP_NAME/" runtime-configs/tpk8s/tanzu-config/genai-service-binding.yml > .tanzu/config/genai-service-binding.yml
    $SED_INPLACE_COMMAND "s|CHAT_SERVICE_NAME|$CHAT_SERVICE_NAME|" .tanzu/config/genai-service-binding.yml 
    $SED_INPLACE_COMMAND "s|EMBEDDINGS_SERVICE_NAME|$EMBEDDINGS_SERVICE_NAME|" .tanzu/config/genai-service-binding.yml
    
   
    sed "s/APP_NAME/$APP_NAME/" runtime-configs/tpk8s/tanzu-config/postgres-external-service.yml > .tanzu/config/postgres-external-service.yml
    $SED_INPLACE_COMMAND "s|PGVECTOR_SERVICE_NAME|$PGVECTOR_SERVICE_NAME|" .tanzu/config/postgres-external-service.yml
    $SED_INPLACE_COMMAND "s/PGVECTOR_HOST/$PGVECTOR_HOST/" .tanzu/config/postgres-external-service.yml
    $SED_INPLACE_COMMAND "s/PGVECTOR_PORT/$PGVECTOR_PORT/" .tanzu/config/postgres-external-service.yml
    $SED_INPLACE_COMMAND "s/PGVECTOR_USERNAME/$PGVECTOR_USERNAME/" .tanzu/config/postgres-external-service.yml
    $SED_INPLACE_COMMAND "s|PGVECTOR_PASSWORD|$PGVECTOR_PASSWORD|" .tanzu/config/postgres-external-service.yml

    sed "s/APP_NAME/$APP_NAME/" runtime-configs/tpk8s/tanzu-config/postgres-service-binding.yml > .tanzu/config/postgres-service-binding.yml
    $SED_INPLACE_COMMAND "s|PGVECTOR_SERVICE_NAME|$PGVECTOR_SERVICE_NAME|" .tanzu/config/postgres-service-binding.yml 

    rm .tanzu/*.bak
    rm .tanzu/config/*.bak
}

#create-db-service
create-db-service () {
    dbname=$1
    echo && printf "\e[37mℹ️  Create $dbname service ...\e[m\n" && echo

    cf create-service postgres $PGVECTOR_PLAN_NAME $dbname -c "{\"svc_gw_enable\": true}" -w
	printf "Waiting for service $dbname to create."
	while [ `cf services | grep 'in progress' | wc -l | sed 's/ //g'` != 0 ]; do
  		printf "."
  		sleep 5
	done

	echo "$dbname creation completed."
}

#create-ai-services
create-ai-services () {
    echo && printf "\e[37mℹ️  Creating $CHAT_SERVICE_NAME and $EMBEDDINGS_SERVICE_NAME GenAI services ...\e[m\n" && echo

    cf create-service genai $CHAT_PLAN_NAME $CHAT_SERVICE_NAME 
    cf create-service genai $EMBEDDINGS_PLAN_NAME $EMBEDDINGS_SERVICE_NAME 
}

#deploy cf 
deploy-cf () {

    cp src/main/resources/static/index_with_ai.html src/main/resources/static/index.html  
    mvn clean package -DskipTests
  	
    create-db-service $PGVECTOR_SERVICE_NAME
    create-ai-services

    echo && printf "\e[37mℹ️  Deploying $APP_NAME application ...\e[m\n" && echo
    cf push $APP_NAME -f runtime-configs/tpcf/manifest.yml --no-start

    echo && printf "\e[37mℹ️  Binding services ...\e[m\n" && echo

    cf bind-service $APP_NAME $PGVECTOR_SERVICE_NAME
    cf bind-service $APP_NAME $CHAT_SERVICE_NAME
    cf bind-service $APP_NAME $EMBEDDINGS_SERVICE_NAME
    cf start $APP_NAME
}

#deploy cf without ai assist
deploy-cf-no-ai () {
    
    cp src/main/resources/static/index_no_ai.html src/main/resources/static/index.html  
    mvn clean package -DskipTests
    cp src/main/resources/static/index_with_ai.html src/main/resources/static/index.html

    create-db-service $BASE_APP_DB

    cf push $BASE_APP_NAME -f runtime-configs/tpcf/manifest.yml --no-start
    cf bind-service $BASE_APP_NAME $PGVECTOR_SERVICE_NAME
    cf start $BASE_APP_NAME
    
}

#deploy k8s
deploy-k8s () {

    echo && printf "\e[35m▶ tanzu deploy and bind \e[m\n" && echo
    tanzu deploy -y
}    

#cleanup
cleanup () {

    cf delete-service $PGVECTOR_SERVICE_NAME -f
    cf delete-service $BASE_APP_DB -f
    cf delete-service $CHAT_SERVICE_NAME -f
    cf delete-service $EMBEDDINGS_SERVICE_NAME -f
    cf delete $APP_NAME -f -r
    cf delete $BASE_APP_NAME -f -r
}

#incorrect usage
incorrect-usage() {
        
     echo && printf "\e[31m⏹ Incorrect usage. Please specify one of the following: \e[m\n"
     echo
     echo "  prepare-k8s [registry name at harbor.vmtanzu.com]"
     echo "  deploy-cf"
     echo "  deploy-cf-no-ai"
     echo "  deploy-k8s"
     echo "  cleanup"
     echo
     exit
}
#################### main ##########################
case $1 in
prepare-k8s)
    if [[ "$2" == "" ]]; then incorrect-usage ; fi
    prepare-k8s $2
    ;;
deploy-cf)
    deploy-cf
    ;;
deploy-cf-no-ai)
    deploy-cf-no-ai
    ;;
deploy-k8s)
    deploy-k8s
    ;;
cleanup)
    cleanup
    ;;
*)
    incorrect-usage
    ;;
esac