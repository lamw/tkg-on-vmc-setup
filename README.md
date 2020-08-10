# Tanzu Kubernetes Grid (TKG) on VMware Cloud on AWS Automation Setup Script


## Pre-Req
* PowerCLI Core 6.0+
* Already deployed 1-Node or larger VMware Cloud on AWS SDDC
* Refresh Token scoped to VMware Cloud on AWS Service

## Instructions

**Step 1** - Download the **setup_vmc_sddc_for_tkg.ps1** PowerCLI script to your desktop and update the variables based on your environment.

**Step 2** - Start the script by running the following command:

```
./setup_vmc_sddc_for_tkg.ps1
```

The script should take ~7 minutes to complete which will automatically setup and deploy all prerequisite steps for running TKG on VMware Cloud on AWS. Once completed, you should see a message providing the Public IP Address that has been allocated to connect to TKG Demo Appliance over SSH.

Here is an example output for successfully running the script:

```
Connecting to VMC ...

Creating Segment tkg-network ...
Successfully created new NSX-T Segment tkg-network

Creating Compute Gateway Groups ...
Successfully created new NSX-T Group Desktop

Successfully created new NSX-T Group SDDC Management

Successfully created new NSX-T Group TKG Network

Creating Management Gateway Groups ...
Successfully created new NSX-T Group Desktop

Successfully created new NSX-T Group TKG Network

Creating Compute Gateway Firewall Rules ...
Successfully created new NSX-T Firewall Rule Desktop to TKG Network

Successfully created new NSX-T Firewall Rule TKG Network to SDDC Management

Creating Management Gateway Firewall Rules ...
Successfully created new NSX-T Firewall Rule Desktop to vCenter Server

Successfully created new NSX-T Firewall Rule TKG Network to vCenter Server

Allocating Public IP for TKG Demo Appliance ...
Successfully requested new NSX-T Public IP Address

Creating NAT Rule for TKG Demo Appliance ...
Successfully create new NAT Rule

Connecting to VMC vCenter Server ...

Connecting TKG Resource Pool ...

Connecting TKG VM Folder ...

Subscribing to TKG Demo Content Library ...
Waiting for initial sync of TKG Demo Content Library ...
Waiting for initial sync of TKG Demo Content Library ...
Waiting for initial sync of TKG Demo Content Library ...
Waiting for initial sync of TKG Demo Content Library ...
Waiting for initial sync of TKG Demo Content Library ...

Deploying TKG HA Proxy OVA ...

Deploying TKG K8S 1.18.x OVA ...

Deploying TKG K8S 1.17.x OVA ...

Deploying TKG Demo Appliance OVA ...

Powering On TKG Demo Appliance VM...

TKG Demo Deployment on VMware Cloud AWS has completed!
You can now SSH to the TKG Demo Appliance at a.b.c.d
StartTime: 08/10/2020 10:48:09
  EndTime: 08/10/2020 10:55:05
Duration: 6.92 minutes
```