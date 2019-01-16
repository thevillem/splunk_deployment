### Splunk Deployment Class

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
