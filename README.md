### Splunk Deployment Class

#### Get Your Public IP

Linux Systems && OS X:
 
    host myip.opendns.com resolver1.opendns.com | grep -E '\d{1,3}(\.\d{1,3}){3}$' | cut -d' ' -f4 | tr -d '\n' > public_ip.txt
    
For Windows, you'll need to run the `my_ip.ps1` Powershell Script.

After running one of the above commands, you should have a file called public_ip.txt. If you don't, raise your hand.

#### Creating a SSH Key

Please follow along with me as I walk you through the AWS console to create a SSH public and private key pair.

#### Indexer Installation

The Splunk installation has been automated for you in order to focus on the deployment configuration.

To perform the install:

1. Navigate to the `/var/tmp` directory  
    `cd /var/tmp/`
    
2. Change the permisson of the installation script  
    `chmod +x indxr_install.sh`
    
    
3. Finally execute the script  
    `./indxr_install.sh`
    
    
If the installation is successful you'll see a success message. If it's not, then navigate to the following folder;

`cd /var/tmp/indxr-install`

 
 And look at the log files there, if you need help please raise your hand.

#### Splunk Indexer Configuration

We are able to search the local host logs, but we want to be able to search our remote host logs. 

##### Setting up Remote Inputs

In order to setup remote inputs, we must modify the following file;

`nano /opt/splunk/etc/system/local/inputs.conf`

We want to configure inputs from Splunk forwarders to this indexer, in order to do this add the following lines;

            
    [splunktcp://:9997]  
    connection_host = dns
    
This setups a TCP port on 9997 that allows other Splunk instances to forward data to.

This would not work in the case of syslog, but there are better tools at handling syslog streams than Splunk. [This .conf presentation from 2017](https://conf.splunk.com/files/2017/slides/the-critical-syslog-tricks-that-no-one-seems-to-know-about.pdf) is a great guide for integrating Splunk and syslog-ng.
            
##### Deployment Apps

Now that we are able to receive logs from remote Splunk forwarders, we need to tell forwarders what data to send.

This can be accomplished with deployment apps, first we want to install the deployment app. To do that we need to download the application;

1. Change to the deployment-app directory on the Splunk Indexer.  
     
     `cd /opt/splunk/etc/deployment-apps`
     
2. Download the Splunk Add-on for Unix

      `curl -O https://s3.amazonaws.com/splunk-class-uf/splunk-add-on-for-unix-and-linux_601.tgz` 

3. Extract the archive into the directory

      `tar -xzf splunk-add-on-for-unix-and-linux_601.tgz`
      
4. You should now have a folder called `Splunk_TA_nix`
     
With the deployment app installed, we now need to tell Splunk to deploy it to hosts.     
     
1. Create a new file called serverclass.conf.
 
      `nano /opt/splunk/etc/system/local/serverclass.conf`
      
2. In this file, we need to add the following lines;

    
    [global]  
        
    [serverClass:Linux]
    whitelist.0=*
    
    [serverClass:Linux:app:Splunk_TA_nix]
    machineTypesFilter=linux-i686, linux-x86_64
    
This tells Splunk to deploy our app `Splunk_TA_nix` to hosts that are either 32-bit or 64-bit Linux hosts.

##### Indexer - Final Steps

Now that the indexer is configured the way we want it, we'll want to verify our configuration.

1. Change to the `splunk\bin` directory

     `cd /opt/splunk/bin/`
     
2. Run Splunk btool, which checks our configs for any issues

    `./splunk btool check --debug`
    
3. If there are any issues, please raise your hand and let a helper know. If there are no issues, then reload Splunk.

    `./splunk restart`


#### Forwarder Installation

The forwarder installation has been automated for you in order to focus on the deployment configuration.

To perform the install:

1. Navigate to the `/var/tmp` directory  
    `cd /var/tmp/`
    
2. Change the permisson of the installation script  
    `chmod +x uf_install.sh`
    
3. Finally execute the script  
    `./uf_install.sh`
    
If the installation is successful you'll see a success message. If it's not, then navigate to the following folder;

 `cd /var/tmp/uf-install`
 
 And look at the log files there, if you need help please raise your hand.
 
 #### Forwarder Configuration
 
 We want to be able to send our logs from this host to our configured indexer.
 
 In order to do this, we need to create the `outputs.conf` file.
 
1. Change your directory.
 
    `cd /opt/splunkforwarder/etc/system/local`
    
2. Create the `outputs.conf` file.
 
    `nano outputs.conf`
    
3. Now we need to add our configuration.
 
 
    [tcpout]
    defaultGroup=indexers

    [tcpout:indexers]
    server=<ip-of-your-indexer>:9997
    
With the outputs.conf file, the forwarder will now send the log that it gathers to our indexer.

The problem we face now is, outside of the internal Splunk logs, our forwarder doesn't send anything else.

We need to tell our forwarder to get apps from our deployment-server, that way we can start getting more information about our system.

1. Create the file `deploymentclient.conf`

    `nano deploymentclient.conf`
    
2. Fill in our configuration


    [deployment-client]
    
    [target-broker:deploymentServer]
    targetUri = <ip-of-your-indexer>:8089
    
With the deployment client file setup, our forwarder will now check our deployment server for any apps it needs.

##### Forwarder - Final Steps

Now that the forwarder is configured the way we want it, we'll want to verify our configuration.

1. Change to the `splunk\bin` directory

     `cd /opt/splunkforwarder/bin/`
     
2. Run Splunk btool, which checks our configs for any issues

    `./splunk btool check --debug`
    
3. If there are any issues, please raise your hand and let a helper know. If there are no issues, then reload Splunk.

    `./splunk restart`
    
 
