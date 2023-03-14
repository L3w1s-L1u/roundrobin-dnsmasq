# roundrobin-dnsmasq

An iptables-based round-robin load balanced dns caching server.

This requirement is inspired by [this post](https://superuser.com/questions/1540076/is-it-possible-to-round-robin-dns-requests/1544801#1544801) and should be considered as an alternative to a nginx+ enabled DNS load balancing system if you are not ready to pay for "nginx+" features.

## Overview 

This project creates a docker-compose file for you to run several dnsmasq containers and load balancing them in a round-robin fashion using iptables' statistic module.

```
                                   __________
                             .--->| dnsmasq1 |----> upstream dns1
dns query  _______________   |    |__________|
--------->|iptables DNAT |---|	   __________
          |______________|   |--->| dnsmasq2 |----> upstream dns2
            load balancer    |    |__________|
                             |     __________
                             |--->| dnsmasqN |----> upstream dns3
                                  |__________|
                    docker container: local caching server
                                  
```
## Quick Start

Prerequisite:

In order to preserve your original iptables settings, "iptables-persistent" should be installed first.

1. `cd` into project root directory and run `deploy.sh`:

```bash
	$ sudo ./deploy.sh
	
```
2. Input  upstream DNS server name and ip address. Server name only serves as a reference and the only thing that matters is the ip address:

```bash
Please provide upstream public DNS names and IPs ...

Please enter a public DNS name, enter "NO" to finish adding: google

Please enter IPv4 address of google: 8.8.8.8

```
3. Keep giving upstream dns servers as you wish or input "NO" to stop.

```bash
Please enter a public DNS name, enter "NO" to finish adding: NO
Upstream DNS count: 3
Upstream DNS list:  google 8.8.8.8 google2 8.8.4.4 cloudflare 1.1.1.1

```
4. Input your local DNS server's IP address, as well as a local interface to listen:

```bash
Please enter local DNS server IPv4 address: 192.168.101.11

Please enter local interface to listen (e.g. eth0): eth0
Local IP: 192.168.101.11
Local interface: eth0

```
**NOTE**: Since we are using docker containers to run dnsmasq, we can not bind to specific interface. Here we collect a local interface to keep dhcp disabled on it. See `/etc/dnsmasq.conf` for more details.

5. Confirm above information, then a docker compose file and docker container runtime directories, as well as dnsmasq config files respectively, will be created:

```bash
Above upstream and local DNS config correct? [Y/N]y
generating compose and config files ...
generate service entry for upstream: google
generate config file for upstream: 8.8.8.8
created upstream dir: /srv/roundrobin-dnsmasq/google
generate service entry for upstream: google2
generate config file for upstream: 8.8.4.4
created upstream dir: /srv/roundrobin-dnsmasq/google2
generate service entry for upstream: cloudflare
generate config file for upstream: 1.1.1.1
created upstream dir: /srv/roundrobin-dnsmasq/cloudflare
Generated /srv/roundrobin-dnsmasq/docker-compose.yml, dnsmasq.conf
Save current iptable rules ...
Current iptable rules saved as /etc/iptables/rules.v4.default
Adding iptables rules ...
Modified iptables saved as /etc/iptables/rules.v4.roundrobin-dnsmasq.
All rules added. Please run "docker-compose up" to bring up your dns caching servers.

```
6. Run docker compose to bring up your dns caching server clusters and iptables will load balance them in a round-robin fashion.

```bash
sudo docker-compose up
[sudo] password for lewis:
Creating dns-google ...
Creating dns-google2 ...
Creating dns-cloudflare ...
Creating dns-google2
Creating dns-google
Creating dns-google ... done
Attaching to dns-cloudflare, dns-google2, dns-google
dns-cloudflare    | [webproc] 2023/03/13 12:25:38 loaded config files changes from disk
dns-cloudflare    | [webproc] 2023/03/13 12:25:38 agent listening on http://0.0.0.0:8080...
dns-google2       | [webproc] 2023/03/13 12:25:40 loaded config files changes from disk
dns-google2       | [webproc] 2023/03/13 12:25:40 agent listening on http://0.0.0.0:8080...
dns-google        | [webproc] 2023/03/13 12:25:41 loaded config files changes from disk
dns-google        | [webproc] 2023/03/13 12:25:41 agent listening on http://0.0.0.0:8080...
dns-cloudflare    | dnsmasq: started, version 2.80 cachesize 1500
dns-cloudflare    | dnsmasq: compile time options: IPv6 GNU-getopt no-DBus no-i18n no-IDN DHCP DHCPv6 no-Lua TFTP no-conntrack ipset auth no-DNSSEC loop-detect inotify dumpfile
dns-google2       | dnsmasq: started, version 2.80 cachesize 1500
dns-cloudflare    | dnsmasq: using nameserver 1.1.1.1#53
dns-google2       | dnsmasq: compile time options: IPv6 GNU-getopt no-DBus no-i18n no-IDN DHCP DHCPv6 no-Lua TFTP no-conntrack ipset auth no-DNSSEC loop-detect inotify dumpfile
dns-google2       | dnsmasq: using nameserver 8.8.4.4#53
dns-cloudflare    | dnsmasq: read /etc/hosts - 7 addresses
dns-google2       | dnsmasq: read /etc/hosts - 7 addresses
dns-google        | dnsmasq: started, version 2.80 cachesize 1500
dns-google        | dnsmasq: compile time options: IPv6 GNU-getopt no-DBus no-i18n no-IDN DHCP DHCPv6 no-Lua TFTP no-conntrack ipset auth no-DNSSEC loop-detect inotify dumpfile
dns-google        | dnsmasq: using nameserver 8.8.8.8#53
dns-google        | dnsmasq: read /etc/hosts - 7 addresses

```
7. Test dns resolve with some names

```bash
	$dig @192.168.101.11 -4 www.bing.com
```

## Maintenance

### Modify DNSMasq Configuration

After all resolver containers start up, you could use a simple web interface pre-integrated in this dnsmasq docker image to modify your resolver's configuration: http://\<listen_address\>:\<web_management_port\>.

Where "listen_address" is your DNS server's IP used to receive all DNS queries and "web_management_port" is generated by script as "538x" which you could find in docker compose file.

### Debug

To reload resolvers:

1. Stop all resolver containers

```
    ../roundrobin-dnsmasq$ docker-compose down

```

2. Restore iptables rules before running resolvers

```
    $iptables-restore < /etc/iptables/rules.v4.default
```

3. Modify dnsmasq config files or docker-compose file and re-run compose.

## Known Issues

dig using lo interface will get abnormal reply:

```
$dig -4 www.bing.com
;; reply from unexpected source: 127.0.0.1#5302, expected 127.0.0.1#53

```
