# Azure Vwan Routemap lab - novpn

This creates a vwan and a few spoke vnets with VM's connected to the vhub and a c8000v in spoke3 bgp peered to the vhub. The creates 2 routemaps, 1 prepends an AS to the spoke2 vnet route sent to spoke3 and another that modifies the route that spoke2 gets from spoke3. You'll be prompted for the resource group name, location where you want the resources created, your public ip and username and password to use for the VM's. NSG's are placed on the default subnets of each vnet allowing RDP access from your public ip. This also creates a logic app that will delete the resource group in 24hrs.

The topology will look like this:
![wvanlabwithroutemaps-novpn](https://github.com/user-attachments/assets/596b7c5f-6c19-4338-bdd9-e77269fb94c9)

You can run Terraform right from the Azure cloud shell by cloning this git repository with "git clone https://github.com/quiveringbacon/AzureVwanRoutmaplab-novpn.git ./terraform".

Then, "cd terraform" then, "terraform init" and finally "terraform apply -auto-approve" to deploy.
