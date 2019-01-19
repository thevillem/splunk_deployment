$wc=New-Object net.webclient
$wc.downloadstring("http://checkip.dyndns.com") -replace "[^\d\.]" >public_ip.txt