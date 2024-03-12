# MA - Mission Analytics

## Infrastructure Installation

### Deployment Steps
By default, setup will be using the Azure Cloud CLI except where it advised to use other tools.

#### Preperation
- Upload all files excluding the Docker tar images to the Azure CLI storage where you will be working from

### Make sure that you are in NMA subscription
please follow a command and check.
```powershell
    az account show
-if you dont have have any other subsciption please use this command.
    az account set --subscription "subcription id" 

#### Azure Cloud Shell
1. Create RG (Resource Group)
    1. Deploy the infrastructure
        ```powershell
        az group create --name 'maportal' --location northeurope
        ```

2. ACR (repo)
    1. Deploy the infrastructure
        ```powershell
        az deployment group create --resource-group 'maportal' --template-file .\acr.bicep
        ```

3. AKS (K8s)
    1. Deploy the infrastructure
        ```powershell
        az deployment group create --resource-group 'maportal' --template-file .\Iac\aks.bicep
        ```

4. Link AKS -> ACR
    1. In the commandline 
        ```powershell
        az aks update -n 'maaks' -g 'maportal' --attach-acr 'maportalrepo'
        ```

5. PostgreSQL (Portal/UDM)
    1. Deploy the infrastructure
        ```powershell
        az deployment group create --resource-group 'maportal' --template-file .\Iac\postgresDB.bicep
        ```
    2. Config DB to allow local and AKS IPs
        1. Use the Web UI to set the IPs for the Flex Server access
    3. Create and Config DB Users and allow them to login
        1. Account for the Portal access
            ```sql
            CREATE USER "portaluser" WITH PASSWORD 'password';
            ALTER ROLE "portaluser" WITH LOGIN;
            ```
        2. Account for UDM access
            ```sql
            CREATE USER "udmuser" WITH PASSWORD 'password';
            ALTER ROLE "udmuser" WITH LOGIN;
            ```
    4. Create DB DBs (AKS / Portal)
        1. Create portal database
            ```sql
            CREATE DATABASE portal;
            ```
        2. Create udm database
            ```sql
            CREATE DATABASE udm;
            ```
    5. Assign new users to databases
        1. Give portaluser user access to portal database
            ```sql
            \c portal
            GRANT ALL PRIVILEGES ON DATABASE portal TO "portaluser";
            GRANT USAGE ON SCHEMA public TO portaluser;
            GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO portaluser;
            GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO portaluser;
            ```
        2. Give udmuser user access to udm database
            ```sql
            \c udm
            GRANT ALL PRIVILEGES ON DATABASE udm TO "udmuser";
            (Create all the schemas first CREATE SCHEMA schemaname)
            GRANT USAGE ON SCHEMA public TO udmuser;
            GRANT USAGE ON SCHEMA udm TO udmuser;
            GRANT USAGE ON SCHEMA events TO udmuser;
            GRANT USAGE ON SCHEMA geonames TO udmuser;
            GRANT USAGE ON SCHEMA queue TO udmuser;
            GRANT USAGE ON SCHEMA social_media TO udmuser;
            GRANT USAGE ON SCHEMA users TO udmuser;

            GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO udmuser;
            GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA udm TO udmuser;
            GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA events TO udmuser;
            GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA geonames TO udmuser;
            GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA queue TO udmuser;
            GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA social_media TO udmuser;
            GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA users TO udmuser;

            GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO udmuser;
            
            GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA udm TO udmuser;
            GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA events TO udmuser;
            GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA geonames TO udmuser;
            GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA queue TO udmuser;
            GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA social_media TO udmuser;
            GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA users TO udmuser;
            ```
    6. Install UDM Schema  
        Make sure that the copy of the schema is located in your Azure storage drive for the Azure Cloud Client
        Connect into the udm datbase and install the schema and tables for the udm
            ```sql
            \c udm;
            \i udm-v1.sql;
            ```
    7. Install Portal Schema
        Make sure that the copy of the schema is located in your Azure storage drive for the Azure Cloud Client
        Connect into the portal datbase and install the schema and tables for the portal
            ```sql
            \c portal;
            \i portal-v1.sql;
            ```

6. Elasticsearch Cluster Configuration
    1. Deploy the infrastructure
        ```powershell
        az deployment group create --resource-group 'maportal' --template-file .\Iac\elasticsearch.bicep
        ```
    2. Deploy Bastion to VM es1 to access the cluster
    3. Do OS updates
    4. Install elasticsearch service on each instance using a Bastion
        1. Download and install the public key
            ```bash
            wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
            ```
        2. Make sure that the supporting packages are installled
            ```bash
            sudo apt-get install apt-transport-https
            ```
        3. Save the repository definition
            ```bash
            echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-7.x.list
            ```
        4. Install the ElasticSearch packages
            ```bash
            sudo apt-get update && sudo apt-get install elasticsearch
            ```
    5. Configuration on each VM
        1. Make sure that the `/etc/elasticsearch/jvm.options` configuration for memory `Xmx` and `Xms` are set to 50% of the total RAM of the VM.
        2. In the `/etc/elasticsearch/elasticsearch.yml` file that you make sure the following fields are enabled and configured
            1. `path.data` = Keep the same unless using additional disk drives to store
            2. `path.logs` = Keep the same unless using additional disk drives to store
            3. `cluster_name` = `maelastic`
            4. `discovery.seed_hosts` = `["es1", "es2", "es3"]`
            5. `cluster.initial_master_nodes` = `["es1", "es2", "es3"]`
            6. `network.host` = `0.0.0.0` so it can listen on all network devices
        3. Restart the service
            ```bash
            sudo service elasticsearch restart  
            ```
    
7. Auth Cluster
    1. Deploy the infrastructure
        ```powershell
        az deployment group create --resource-group 'maportal' --template-file .\Iac\auth.bicep
        ```

8. Auth Cluser Configuration  
    ##### Server 1
    1. Windows Server 2022 Datacenter Azure version
    2. Fail over option enabled
    3. Auto update disabled
    4. Set to manual
        1. (This is to help control when updates and restarts are done)
        2. Create a new user with Admin permissions using the Local Users and Groups
        3. Username - adlds
        4. Make sure that only options are enabled
            1. User cannot change password
            2. Password never expires
            3. Add the new user to the local Administrators Group
    5. Add Role
        1. Click `OK`, till you get to the list of roles
        2. Click on `AD LDS` option
        3. Click `OK`, till you get to the screen that it starts the installation
        4. Click `Close` when installation is completed
    6. Config Role
        1. Click on the yellow flag
        2. Click on run `ADLDS` setup wizard
        3. Make sure that `A Unique instance` is selected
        4. Set instance name to `lds-01`
        5. Leave port numbers the same
        6. Click on `Yes`, Create an Application directory Partition
            ```ldap
            CN=portals,DC=ma,DC=local
            ```
        7. Use the option to select the user to have LDS use to run.
            1. Use the account created early adlds
            2. Select `ok`
            3. Select `ok` when asked to add permission to run as service
        8. Select the LDS user as the user that has admin access
        9. Go ahead and select all `LDIF` options to load
        10. Click `next` till it finishes.
            1. You might need to put in the new admin account info when asked
            2. Username will be local\adlds
            3. At the Dashboard make sure that all Roles are status Green
    
    ##### Server 2
    1. Repeat the above steps except the differences are
        1. Name the server lds-02
        2. Select `replica server` instead of new server
        3. when asked, put in the lds-01 server account information above
        4. The replica server should connect with each other.
        5. Follow any additional steps if asked.


    ##### Creating Portal Admin
    1. Remote into lds-01
    2. Open up the `ADSI Editor`
        1. This can be found by clicking the `Tools` in the top right of the window
    3. Connect into the AD LDS service
        1. Click on `Action` then `Conntect to ...`
        2. Under `Connection Point` make sure that `Select or Type...` is selected
        3. In the field put in the path `CN=portals,DC=ma,DC=local`
        4. Under `Computer` make sure that the `Select or Type...` is selected
        5. In that field, put in `localhost`
        6. Click `OK`
    4. Create Container for the user accounts. This would be the name of the instance that you are deploying
        1. Right click on `CN=portals,DC=ma,DC=local`
        2. Select `New` and `Object`
        3. Make sure `container` is selected and then select `Next`
        4. Put in `maportal` and then click `Next` then `Finish`
    5. Create Admin user account
        1. Right click `maportal`
        2. Select `New` and `Object...`
        3. Make sure `inetOrgPerson` is selected then `Next`
        4. Put in `portaladmin` for the account name or the one you wish to use
        5. Click `Next` and `Finish`
    6. Setting permissions for the Admin user
        1. Right click `CN=portaladmin`
        2. Click on `Reset Password`
        3. Put in your password. Make sure it meets complex requirements
        4. Right click `CN=portaladmin` again then select `Properties`
        5. Make sure the attribute `msDS-UserAccountDisabled` is set to `False`
        6. Make sure the attribute `sn` and `uid` are set to `maadmin`
        7. Click `OK` when done
        8. Under `Roles` right click `CN=Administrators`
        9. Then select `Properties`
        10. Under the attribute `member` `add DN` `CN=portaladmin,CN=maportal,CN=portals,DC=ma,DC=local`
        11. Click `Ok` when completed

<br>

9. Deploy Loads Balancer for both the ElasticSearch cluster and the Auth cluster
    1. Make sure that the load balancers are setup as a private one
    2. Have the backend node pools linked to each VM in the respected cluster
        1. ElasticSearch to ElasticSearch VMs
        2. Auth to Auth VMs (LDS)
    3. The backend ports and frontend ports should be the same
        1. Elasticsearch => port `9200`
        2. Auth => port `636` (SSL) and `389` (PLAINTEXT)
10. Private Link Services
    1. Create Private links for each load balancer in each vNet
11. Private End Points
    1. Create End Pionts for each of those Private Links
    2. Connect them to the AKS vNet. This will ensure that the services deployed in the AKS are able  
    to talk to the ES and Auth cluster

#### Local Azure CLI, Docker
12. Load up Images to ACR (Using Local Azure CLI and Docker Desktop)
    1. Load the Tar files into local Docker
        ```powershell
        docker load --input <image_name.tar>
        ```

    2. Retag the newly uploaded images to use the ACR
        ```powershell
        docker tag image_id maportalrepo.azurecr.io/<image_name>
        ```

    3. log into the ACR
        1. AZ CLI login to the Acure Account
            ```powershell
            az login
            ```
        2. AZ CLI ACR login
            ```powershell
            az acr login -n maportalrepo
            ```

    4. Upload the images to ACR
        ```powershell
        docker push maportalrepo.azurecr.io/<image_name>
        ```

<br>

#### Azure Cloud CLI
1. Generate JWT certificates that are used for the services
    1. Run the commands to generate the Public and Private Keys
        ```powershell
        openssl genrsa -out private-key.pem 3072
        openssl rsa -in private-key.pem -pubout -out public-key.pem
        '''
    2. Encode the certs to base64 for kubernetes. Save the output for Graphql and Fjord service where they request the Keys
        '''powershell
        base64 -w0 private-key.pem
        base64 -w0 public-key.pem
        '''
2. Go into the `Deployment` directory
    ```powershell
    cd Deployment
    ```
3. Create a Kubernetes namespace to deploy the services to.
    ```powershell
    kubectl create namespace production
    ```
4. Graphql
    1. K8s Secrets
        1. Deploy secret template
            ```powershell
            kubectl create -f .\K8s_secrets\graphql.yaml --namespace production
            ```
        2. Edit the secret with values
            ```powershell
            kubectl edit secrets graphql --namespace production
            ```
        3. Using the `.\Scripts\secret_encode.ps1` script, encode the strings to base64 encodeing
        4. Update the values in the secret with the base64 string values
        5. Save and exit
    3. Deploy the service
        1. Using Helm
            ```powershell
            helm upgrade graphql graphql --install --namespace production
            ```
5. MA-service
    1. Deploy the service
        1. Using Helm
            ```powershell
            helm upgrade service service --install --namespace production
            ```
6. Fjord
    1. K8s Secrets
        1. Deploy secret template
            ```powershell
            kubectl create -f .\K8s_secrets\fjord.yaml --namespace production
            ```
        2. Edit the secret with values
            ```powershell
            kubectl edit secrets fjord --namespace production
            ```
        3. Using the `.\Scripts\secret_encode.ps1` script, encode the strings to base64 encodeing
        4. Update the values in the secret with the base64 string values
        5. Save and exit 
    3. Deploy the service
        ```powershell
        helm upgrade fjord fjord --install --namespace production
        ```
7. Udm2es-dal
    1. K8s Secrets
        1. Deploy secret template
            ```powershell
            kubectl create -f .\K8s_secrets\udm2esdal.yaml --namespace production
            ```
        2. Edit the secret with values
            ```powershell
            kubectl edit secrets udm2esdal --namespace production
            ```
        3. Using the `.\Scripts\secret_encode.ps1` script, encode the strings to base64 encodeing
        4. Update the values in the secret with the base64 string values
        5. Save and exit
    2. Deploy the service
        ```powershell
        helm upgrade udm2esdal udm2esdal --install --namespace production
        ```
    3. Deploy


<br>


#### The below will need to be deployed and configured for external/public access
The below steps will are done based the environment, Domain purchases, and related configs. It is recommned to follow the recommend  
configs from Azure if using Azure Application Gateway or if using external software like Apache or Nginx, please follow their configs.  
  
Some notes for the deployment are:
- Use a FQDN vs an IP address when accessing the Portal
- Configure you gateway to access the graphql service via the same FQDN and port as the portal and route based on URL
    - `/graphql` -> `<graphql_service>/graphql`
    - `/subscription` -> `<graphql_service>/subscriptions`
    - `/*` -> `<portal_service>/`
- Make sure that the Fjord deployment config environment variables are using the FQDN. This is needed as that is the URL that  
  is passed to the client's browser to then connect to the graphql service. The variables are listed below:
    ```powershell
    kubectl edit deployment fjord --namespace production
    ```
    - `WS_GRAPHQL` (HTTPS:// for ssl)
    - `WS_SUBSCRIPTIONS` (wss:// for ssl)
- To add in access into the services from outside the AKS to the pods. Deploy the services that will create new K8s services for NodePorts.  
  The NodePort port is the external port that can be used at the VM levels to route traffic from a Gateway into the AKS cluster.  
  Make sure to configure the AKS loadbalancer and network security to allow the traffic through.
  ``` powershell
  kubectl create -f K8s-services/graphql-in.yaml -n production
  kubectl create -f K8s-services/portal-in.yaml -n production
  ```
- To view the ports of the ther services-in that was just created.
  ```powershell
  kubectl get services --namespace production
  ```
10. (DNS) Deploy
11. (DNS) Configure
12. (Cert) Purchase
13. (Cert) Config AGW with Certs (Vault)
14. Deploy AGW (Gateway)
15. Config AGW to allow traffic through from Internet
    



#### Installation Notes
- To access the OSes, you will need to install a Bastion on each vNet to access the VMs. You can then use the  
  Azure Web UI under the *Connect* option to connect othem under the VM view.
- In each vNet, the hostnames and IPs are updated in the internal Azure DNS. So you can call the other members  
  of the cluster by using the DNS name vs needing IPs. So you can `ping es2` from VM `es1`.
<br> <br>

## Development Notes
- Template resource for Bicep  
https://learn.microsoft.com/en-us/azure/templates

- Use the Complete mode to remove the deployment using an empty Bicep file
    ```powershell
    az deployment group create --resource-group 'maportal' --template-file empty.bicep --mode complete
    ```

- Save Docker images as tar files
    ```powershell
    docker save --output="image_name.tar" id_image
    ```

