# Demo of Tanzu platform and SpringAI

![Spring Boot](https://img.shields.io/badge/Spring%20Boot-3.1.2-brightgreen.svg)
![AI LLM](https://img.shields.io/badge/AI-LLM-blue.svg)
![PostgreSQL](https://img.shields.io/badge/postgres-15.1-red.svg)
![Tanzu](https://img.shields.io/badge/tanzu-platform-purple.svg)

This repository contains artifacts necessary to build and run generative AI applications using Spring Boot and Tanzu Platform. The instructions below cover setup for both Cloud Foundry (cf) and Kubernetes (k8s) environments.

## Architecture

![Alt text](https://github.com/0pens0/spring-metal/blob/main/image.png?raw=true "Spring-metal AI topology")

## Prerequisites
- Ensure you have the latest version of the Tanzu CLI installed.
- Access to a Route53 domain and necessary AWS permissions.
- Configured egress settings (closed by default) to connect to external services.

## Preperations

- Create a ```.tanzu/config``` and ```.tanzu/services``` folders

- Copy ```runtime-configs/tpk8s/tanzu-changeme/spring-metal.yml``` to ```.tanzu/config``` and update the CHANGE_ME tokens
- Copy ```runtime-configs/tpk8s/tanzu-changeme/httproute.yml``` to ```.tanzu/config``` and update the CHANGE_ME tokens (app name must match info in ```spring-metal.yml```)

- Copy ```runtime-configs/tpk8s/tanzu-changeme/genai-external-service.yml``` to ```.tanzu/services``` and update the CHANGE_ME tokens (all keys must be in 64 bit format)
- Copy ```runtime-configs/tpk8s/tanzu-changeme/genai-service-binding.yml``` to ```.tanzu/services``` and update the CHANGE_ME tokens (app name must match info in ```spring-metal.yml```)

- Copy ```runtime-configs/tpk8s/tanzu-changeme/postgres-external-service.yml``` to ```.tanzu/services``` and update the CHANGE_ME tokens (all keys must be in 64 bit format)
- Copy ```runtime-configs/tpk8s/tanzu-changeme/postgres-service-binding.yml``` to ```.tanzu/services``` and update the CHANGE_ME tokens (app name must match info in ```spring-metal.yml```)

## Installation

### Cloud Foundry Runtime
Set up your target environment and create necessary back-end services for the ai demo; we will only crete services and service-keys on the CF Runtime side:

```bash
cf target -o ai-apps -s ai-spring-metal
cf create-service private-ai-service model-plan ai-service
cf create-service-key ai-service ai-key
cf service-key ai-service ai-key
cf create-service postgres on-demand-postgres-db pgvector
cf create-service-key pgvector pg-key
cf service-key pgvector pg-key
```
Notes:
- The GenAI tile v0.5+ plan name is the chat Model you choose to use (e.g: meta-llama/Meta-Llama-3-8B-Instruct). Adjust to a model configured in your GenAI tile.
- If your Cloud Foundry Runtime services are hosted on a private network, you will need to create or update your postgres service with the TCP Router and Service instance gateway.  [Documentation](https://docs.vmware.com/en/VMware-Tanzu-Postgres-for-Tanzu-Application-Service/1.1/postgres/create-service-gateway-instance.html). Example command in that case: ```cf create-service postgres on-demand-postgres-db pgvector -c '{"svc_gw_enable":  true,"router_group": "default-tcp","external_port": 1028}' -w```
- The contents of your Kubernetes service secret can be viewed through the service key.  
  
### Kubernetes Runtime

Set up your Kubernetes environment ensuring all prerequisites are met:

#### Set context:

```bash
tanzu login
tanzu project use <my-project>
tanzu space use <my-space>
```
## Build

Follow these commands to build your application:

```bash
tanzu build config --containerapp-registry [YOUR CONTAINER REGISTRY] 
tanzu build -o build-output
```

## Deploy

Follow these commands to deploy your application from the build-output folder:

```bash
tanzu deploy --from-build build-output
```

## Bind

#### Create and bind the pre-provisioned services :
Create secrets to external Postgres (with pgvector) and GenAI control apis running on TPCF and bind them as pre-provisioned services 

```bash
tanzu deploy --only .tanzu/services
```
Notes:
- After deploying the Service bindings, a new version of the Pod with the bindings in it will be deployed, once it's read the app shoul dbe able to detect the bindings and apply the llm and postgres profiles, leveraging Postgres as the DB for Albums and Embeddings, and activating the chat bot connected to the GenAI tile API.

### Troubleshooting

#### Issue: Problem with external service binding.
- **Solution:** Ensure that all credentials and connection details in `.tanzu/config/services` are correct and updated.

#### Issue: Application deployment fails.
- **Solution:** Check the build output for errors and verify the Tanzu configuration settings.

Browse your application through the app ingress link provided in the Space UI after deployment.

## Contributing
Contributions to this project are welcome. Please ensure to follow the existing coding style and add unit tests for any new or changed functionality.


