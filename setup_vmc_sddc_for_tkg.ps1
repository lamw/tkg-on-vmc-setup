# VMC Environment
$RefreshToken = "FILL-ME-IN"
$OrgName = "FILL-ME-IN"
$SDDCName = "FILL-ME-IN"

# VMC NSX-T Configuration
$DESKTOP_GROUP_NAME = "Desktop"
$DESKTOP_GROUP_IP = "x.x.x.x" # whatsmyip.com
$SDDC_MGMT_GROUP_NAME = "SDDC Management"
$SDDC_MGMT_GROUP_IP = "10.2.0.0/16" # SDDC CIDR
$TKG_NETWORK_GROUP_NAME = "TKG Network"
$TKG_NETWORK_GROUP_IP = "192.168.2.0/24"
$TKG_NETWORK_SEGMENT_NAME = "tkg-network"
$TKG_NETWORK_GW = "192.168.2.1/24"
$TKG_NETWORK_DHCP_RANGE = "192.168.2.2-192.168.2.254"

# VMC vCenter Server
$VMC_VCENTER = "vcenter.sddc-x-x-x-x.vmwarevmc.com" # replace with your VMC vCenter Server address
$VMC_VCENTER_USERNAME = "cloudadmin@vmc.local"
$VMC_VCENTER_PASSWORD = "FILL-ME-IN" # replace with your VMC vCenter Server password
$TKG_RESOURCE_POOL_NAME = "TKG"
$TKG_VM_FOLDER_NAME = "TKG"

# TKG Demo Appliance
$TKG_DEMO_APPLIANCE_IP = "192.168.2.2"
$TKG_DEMO_APPLIANCE_CIDR = "24 (255.255.255.0)"
$TKG_DEMO_APPLIANCE_GATEWAY = "192.168.2.1"
$TKG_DEMO_APPLIANCE_DNS = "8.8.8.8" # space seperated
$TKG_DEMO_APPLIANCE_DNS_DOMAIN = "vmware.corp"
$TKG_DEMO_APPLIANCE_NTP = "pool.ntp.org" # space seperated
$TKG_DEMO_APPLIANCE_ROOT_PASSWORD = "FILL-ME-IN"

### DO NOT EDIT BEYOND HERE ###

# TKG Content Library
$TKG_CONTENT_LIBRARY_NAME = "TKG-DEMO"
$TKG_CONTENT_LIBRARY_SUBSCRIPTION_URL = "https://download3.vmware.com/software/vmw-tools/tkg-demo-appliance/cl2/lib.json"
$TKG_CONTENT_LIBRARY_SUBSCRIPTION_THUMBPRINT = "ba:c6:4e:d9:ad:d4:53:b5:86:5a:5d:70:36:cf:89:93:d1:6c:f9:63"
$TKG_DEMO_APPLIANCE_LIBRARY_NAME = "TKG-Demo-Appliance-1.1.3"
$TKG_HAPROXY_APPLIANCE_LIBRARY_NAME = "photon-3-haproxy-v1.2.4-vmware.1"
$TKG_K8S_1_18_APPLIANCE_LIBRARY_NAME = "photon-3-kube-v1.18.6_vmware.1"
$TKG_K8S_1_17_APPLIANCE_LIBRARY_NAME = "photon-3-kube-v1.17.9_vmware.1"

Function Set-VMOvfProperty {
    # https://www.virtuallyghetto.com/2017/10/updating-ovf-properties-for-a-vm-using-vsphere-api-and-powercli.html
    param(
        [Parameter(Mandatory=$true)]$VM,
        [Parameter(Mandatory=$true)]$ovfChanges
    )

    # Retrieve existing OVF properties from VM
    $vappProperties = $VM.ExtensionData.Config.VAppConfig.Property

    # Create a new Update spec based on the # of OVF properties to update
    $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
    $spec.vAppConfig = New-Object VMware.Vim.VmConfigSpec
    $propertySpec = New-Object VMware.Vim.VAppPropertySpec[]($ovfChanges.count)

    # Find OVF property Id and update the Update Spec
    foreach ($vappProperty in $vappProperties) {
        if($ovfChanges.ContainsKey($vappProperty.Id)) {
            $tmp = New-Object VMware.Vim.VAppPropertySpec
            $tmp.Operation = "edit"
            $tmp.Info = New-Object VMware.Vim.VAppPropertyInfo
            $tmp.Info.Key = $vappProperty.Key
            $tmp.Info.value = $ovfChanges[$vappProperty.Id]
            $propertySpec+=($tmp)
        }
    }
    $spec.VAppConfig.Property = $propertySpec

    $vm.ExtensionData.ReconfigVM_Task($spec)
}

$StartTime = Get-Date

Import-Module VMware.VMC.NSXT
Write-Host -ForegroundColor Green "Connecting to VMC ..."
Connect-VmcServer -RefreshToken $RefreshToken | Out-Null
Connect-NSXTProxy -RefreshToken $RefreshToken -OrgName $OrgName -SDDCName $SDDCName

# Create Segment
Write-Host -ForegroundColor Green "Creating Segment ${TKG_NETWORK_SEGMENT_NAME} ..."
New-NSXTSegment -Name $TKG_NETWORK_SEGMENT_NAME -Gateway $TKG_NETWORK_GW -DHCP -DHCPRange $TKG_NETWORK_DHCP_RANGE

# Create Compute Gateway Groups
Write-Host -ForegroundColor Green "Creating Compute Gateway Groups ..."
New-NSXTGroup -GatewayType CGW -Name $DESKTOP_GROUP_NAME -IPAddress @($DESKTOP_GROUP_IP)
New-NSXTGroup -GatewayType CGW -Name $SDDC_MGMT_GROUP_NAME -IPAddress @($SDDC_MGMT_GROUP_IP)
New-NSXTGroup -GatewayType CGW -Name $TKG_NETWORK_GROUP_NAME -IPAddress @($TKG_NETWORK_GROUP_IP)

# Create Management Gateway Groups
Write-Host -ForegroundColor Green "Creating Management Gateway Groups ..."
New-NSXTGroup -GatewayType MGW -Name $DESKTOP_GROUP_NAME -IPAddress @($DESKTOP_GROUP_IP)
New-NSXTGroup -GatewayType MGW -Name $TKG_NETWORK_GROUP_NAME -IPAddress @($TKG_NETWORK_GROUP_IP)

# Create Compute Gateway Firewall Rules
Write-Host -ForegroundColor Green "Creating Compute Gateway Firewall Rules ..."
New-NSXTFirewall -GatewayType CGW -Name "Desktop to TKG Network" -SourceGroup @("$DESKTOP_GROUP_NAME") -DestinationGroup @("$TKG_NETWORK_GROUP_NAME") -Service ANY -Logged $true -SequenceNumber 0 -Action ALLOW
New-NSXTFirewall -GatewayType CGW -Name "TKG Network to SDDC Management" -SourceGroup @("$TKG_NETWORK_GROUP_NAME") -DestinationGroup @("$SDDC_MGMT_GROUP_NAME") -Service ANY -Logged $true -SequenceNumber 1 -Action ALLOW

# Create Management Gateway Firewall Rules
Write-Host -ForegroundColor Green "Creating Management Gateway Firewall Rules ..."
New-NSXTFirewall -GatewayType MGW -Name "Desktop to vCenter Server" -SourceGroup @("$DESKTOP_GROUP_NAME") -DestinationGroup @("vCenter") -Service @("HTTPS") -Logged $true -SequenceNumber 0 -Action ALLOW
New-NSXTFirewall -GatewayType MGW -Name "TKG Network to vCenter Server" -SourceGroup @("$TKG_NETWORK_GROUP_NAME") -DestinationGroup @("vCenter") -Service @("HTTPS") -Logged $true -SequenceNumber 1 -Action ALLOW

# Allocate Public IP for TKG Demo Appliance
Write-Host -ForegroundColor Green "Allocating Public IP for TKG Demo Appliance ..."
$publicIp = New-NSXTPublicIP -Name "TKG-Demo-Appliance"

# Create NAT rule for TKG Demo Appliance
Write-Host -ForegroundColor Green "Creating NAT Rule for TKG Demo Appliance ..."
New-NSXTNatRule -Name "TKG-Demo-Appliance" -PublicIP ($publicIp.ip) -InternalIP $TKG_DEMO_APPLIANCE_IP -Service ANY

# Connect to VMC vCenter Server
Write-Host -ForegroundColor Green "Connecting to VMC vCenter Server ..."
Connect-VIServer -Server $VMC_VCENTER -User $VMC_VCENTER_USERNAME -Password $VMC_VCENTER_PASSWORD
Connect-CisServer -Server $VMC_VCENTER -User $VMC_VCENTER_USERNAME -Password $VMC_VCENTER_PASSWORD

# Create TKG Resource Pool
if(!(Get-ResourcePool -Name $TKG_RESOURCE_POOL_NAME -ErrorAction SilentlyContinue)) {
    Write-Host -ForegroundColor Green "Connecting TKG Resource Pool ..."
    New-ResourcePool -Name $TKG_RESOURCE_POOL_NAME -Location (Get-ResourcePool -Name "Compute-ResourcePool")
}

# Create TKG VM Folder
if(!(Get-Folder -Name $TKG_VM_FOLDER_NAME -ErrorAction SilentlyContinue)) {
    Write-Host -ForegroundColor Green "Connecting TKG VM Folder ..."
    New-Folder -Name $TKG_VM_FOLDER_NAME -Location (Get-Folder -Name "vm")
}

# Subscribe to TKG Content Library
Write-Host -ForegroundColor Green "Subscribing to TKG Demo Content Library ..."
New-ContentLibrary -Name $TKG_CONTENT_LIBRARY_NAME -Description 'Subscribed Content Library to TKG Demo Appliance for VMC' -AutomaticSync -Datastore (Get-Datastore -Name "WorkloadDatastore") -SubscriptionUrl $TKG_CONTENT_LIBRARY_SUBSCRIPTION_URL -SslThumbprint $TKG_CONTENT_LIBRARY_SUBSCRIPTION_THUMBPRINT

while( (Get-ContentLibrary "$TKG_CONTENT_LIBRARY_NAME").syncdate -eq $null ) {
    Write-Host "Waiting for initial sync of TKG Demo Content Library ..."
    Start-Sleep -Seconds 60
}

$tkgSegmentId = (Get-VirtualNetwork -Name $TKG_NETWORK_SEGMENT_NAME).Id -Replace ("^OpaqueNetwork-","")
$ovfService = Get-CisService com.vmware.vcenter.ovf.library_item

# Deploy HA Proxy OVA and convert to VM Template
Write-Host -ForegroundColor Green "Deploying TKG HA Proxy OVA ..."
$haProxyItemId = (Get-ContentLibraryItem -Name $TKG_HAPROXY_APPLIANCE_LIBRARY_NAME).Id
$haProxyDeploySpec = $ovfService.help.deploy.deployment_spec.Create()
$haProxyTargetSpec = $ovfService.help.deploy.target.Create()

$haProxyDeploySpec.name = $TKG_HAPROXY_APPLIANCE_LIBRARY_NAME
$haProxyDeploySpec.accept_all_EULA = $true
$haProxyDeploySpec.network_mappings = @{"nic0"=$tkgSegmentId}
$haProxyTargetSpec.folder_id = (Get-Folder -Name "Templates").Id -replace ("^Folder-","")
$haProxyTargetSpec.resource_pool_id = (Get-ResourcePool -Name $TKG_RESOURCE_POOL_NAME).Id -replace ("^ResourcePool-","")
$haProxyDeployResults = $ovfService.deploy($null,$haProxyItemId,$haProxyTargetSpec,$haProxyDeploySpec)
Get-Vm $TKG_HAPROXY_APPLIANCE_LIBRARY_NAME | Set-Vm -ToTemplate -Confirm:$false

# Deploy K8s 1.18 OVA and convert to VM Template
Write-Host -ForegroundColor Green "Deploying TKG K8S 1.18.x OVA ..."
$k8s18ItemId = (Get-ContentLibraryItem -Name $TKG_K8S_1_18_APPLIANCE_LIBRARY_NAME).Id
$k8s18ProxyDeploySpec = $ovfService.help.deploy.deployment_spec.Create()
$k8s18TargetSpec = $ovfService.help.deploy.target.Create()

$k8s18ProxyDeploySpec.name = $TKG_K8S_1_18_APPLIANCE_LIBRARY_NAME
$k8s18ProxyDeploySpec.accept_all_EULA = $true
$k8s18ProxyDeploySpec.network_mappings = @{"nic0"=$tkgSegmentId}
$k8s18TargetSpec.folder_id = (Get-Folder -Name "Templates").Id -replace ("^Folder-","")
$k8s18TargetSpec.resource_pool_id = (Get-ResourcePool -Name $TKG_RESOURCE_POOL_NAME).Id -replace ("^ResourcePool-","")
$k8s18DeployResults = $ovfService.deploy($null,$k8s18ItemId,$k8s18TargetSpec,$k8s18ProxyDeploySpec)
Get-Vm $TKG_K8S_1_18_APPLIANCE_LIBRARY_NAME | Set-Vm -ToTemplate -Confirm:$false

# Deploy K8s 1.17 OVA and convert to VM Template
Write-Host -ForegroundColor Green "Deploying TKG K8S 1.17.x OVA ..."
$k8s17ItemId = (Get-ContentLibraryItem -Name $TKG_K8S_1_17_APPLIANCE_LIBRARY_NAME).Id
$k8s17ProxyDeploySpec = $ovfService.help.deploy.deployment_spec.Create()
$k8s17TargetSpec = $ovfService.help.deploy.target.Create()

$k8s17ProxyDeploySpec.name = $TKG_K8S_1_17_APPLIANCE_LIBRARY_NAME
$k8s17ProxyDeploySpec.accept_all_EULA = $true
$k8s17ProxyDeploySpec.network_mappings = @{"nic0"=$tkgSegmentId}
$k8s17TargetSpec.folder_id = (Get-Folder -Name "Templates").Id -replace ("^Folder-","")
$k8s17TargetSpec.resource_pool_id = (Get-ResourcePool -Name $TKG_RESOURCE_POOL_NAME).Id -replace ("^ResourcePool-","")
$k8s17DeployResults = $ovfService.deploy($null,$k8s17ItemId,$k8s17TargetSpec,$k8s17ProxyDeploySpec)
Get-Vm $TKG_K8S_1_17_APPLIANCE_LIBRARY_NAME | Set-Vm -ToTemplate -Confirm:$false

# Deploy TKG Demo Appliance
Write-Host -ForegroundColor Green "Deploying TKG Demo Appliance OVA ..."
Get-ContentLibraryItem -Name $TKG_DEMO_APPLIANCE_LIBRARY_NAME | New-VM -Name $TKG_DEMO_APPLIANCE_LIBRARY_NAME `
-ResourcePool (Get-ResourcePool -Name $TKG_RESOURCE_POOL_NAME) `
-Location (Get-Folder -Name $TKG_VM_FOLDER_NAME) `
-Datastore (Get-Datastore -Name "WorkloadDatastore") `
-DiskStorageFormat Thin

# Attach to TKG Network
Get-VM -Name $TKG_DEMO_APPLIANCE_LIBRARY_NAME | Get-NetworkAdapter | Set-NetworkAdapter -NetworkName $TKG_NETWORK_SEGMENT_NAME -Confirm:$false

# Configure OVF Properties
$ovfPropertyChanges = @{
    "guestinfo.ipaddress"=$TKG_DEMO_APPLIANCE_IP
    "guestinfo.netmask"=$TKG_DEMO_APPLIANCE_CIDR
    "guestinfo.gateway"=$TKG_DEMO_APPLIANCE_GATEWAY
    "guestinfo.dns"=$TKG_DEMO_APPLIANCE_DNS
    "guestinfo.domain"=$TKG_DEMO_APPLIANCE_DNS_DOMAIN
    "guestinfo.ntp"=$TKG_DEMO_APPLIANCE_NTP
    "guestinfo.root_password"=$TKG_DEMO_APPLIANCE_ROOT_PASSWORD
}

Set-VMOvfProperty -VM (Get-VM -Name $TKG_DEMO_APPLIANCE_LIBRARY_NAME) -ovfChanges $ovfPropertyChanges

# Power On TKG Demo Appliance
Write-Host -ForegroundColor Green "Powering On TKG Demo Appliance VM..."
Start-VM -VM (Get-VM -Name $TKG_DEMO_APPLIANCE_LIBRARY_NAME)

Disconnect-VIServer * -Confirm:$false

$EndTime = Get-Date
$duration = [math]::Round((New-TimeSpan -Start $StartTime -End $EndTime).TotalMinutes,2)

Write-Host -ForegroundColor Cyan "TKG Demo Deployment on VMware Cloud AWS has completed!"
Write-Host -ForegroundColor Cyan "You can now SSH to the TKG Demo Appliance at $($publicIp.ip)"
Write-Host -ForegroundColor Cyan "StartTime: $StartTime"
Write-Host -ForegroundColor Cyan "  EndTime: $EndTime"
Write-Host -ForegroundColor Cyan " Duration: $duration minutes"