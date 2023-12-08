# apt-proxy-detect
Auto detection of apt proxies in the LAN, caching and checking status of it.

# Why this is needed?
Spending 2023 time on this topic sound/reads quite strange but up to now
i struggle with some problems within the solutions i found so far.

Issues:
* No reliable detect proxies via mDns. (Timeouts, not found)
* No caching of the found proxies.
* No check if the found proxy works for the requested target.
* No longer active maintained (deprecated warnings all over the place)

# How does it look?

Example output:
```
dev@dev:~$ apt-proxy-detect.sh 
Service[ER][apt-cacher-ng proxy on squid-deb-proxy]@http://192.168.0.27:3142 
Service[OK][Squid deb proxy on squid-deb-proxy]@http://192.168.0.27:8000 
http://192.168.0.27:8000
```

or with specific checking (failing):
```
dev@dev:~$ apt-proxy-detect.sh github.xyz
Service[ER][apt-cacher-ng proxy on squid-deb-proxy]@http://192.168.0.27:3142 
Service[ER][Squid deb proxy on squid-deb-proxy]@http://192.168.0.27:8000 
```

or within apt context:
```
dev@dev:~$ sudo apt update
Service[OK][Squid deb proxy on squid-deb-proxy]@http://192.168.0.27:8000 
Service[ER][apt-cacher-ng proxy on squid-deb-proxy]@http://192.168.0.27:3142 
Hit:1 http://local-repo.fritz.box/repo-repo trunk InRelease
Hit:2 http://security.debian.org/debian-security bookworm-security InRelease              
Hit:3 http://download.proxmox.com/debian/pve bookworm InRelease                           
Hit:4 http://packages.microsoft.com/repos/code stable InRelease                           
Hit:5 http://deb.debian.org/debian bookworm InRelease
Get:6 http://deb.debian.org/debian bookworm-updates InRelease [52,1 kB]
Hit:7 https://dl.google.com/linux/chrome/deb stable InRelease
Fetched 52,1 kB in 3s (15,9 kB/s)
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
22 packages can be upgraded. Run 'apt list --upgradable' to see them.
```

# How to install?

So the quickest way is:
```
curl -s https://raw.githubusercontent.com/hastmu/apt-proxy-detect/main/install.sh  | sudo bash
```

looks like:
```
dev@dev:~$ curl -s https://raw.githubusercontent.com/hastmu/apt-proxy-detect/main/install.sh  | sudo bash
- check dependencies...
- download latest to: /usr/local/bin/apt-proxy-detect.sh
- set permissions to a+rx
- create/updating /etc/apt/apt.conf.d/30apt-proxy-detect.conf

```

or you just download the install.sh and run it locally.

# How does it work?

The apt.conf.d entry makes apt aware of the tool which is then call during "apt update",
for some reason most of the other tools are not aware that you get the target URL as 
parameter for this call.

This URL is the proxy check URL to confirm that the found or cached proxy is working with
this dedicated URL as some proxies may have white/black lists or just not got configured 
right or outdated for the new stuff to be checked out.

In case a proxy is not serving the URL it is drop for this dedicated URL.

The found (via avahi-browse _apt_proxy._tcp) proxies are cached under /tmp/.apt-proxy.$username
in case this has the wrong owner it is ignored and a waring is issued.

Thats it. Enjoy.

# Debugging

In case of issue you can set "DEBUG_APT_PROXY_DETECT" to get all details, like e.g.:
```
export DEBUG_APT_PROXY_DETECT=1
sudo apt update
```

looks like

```
dev@dev:~$ export DEBUG_APT_PROXY_DETECT=1
dev@dev:~$ sudo apt update
[      INFO]: apt-proxy-detect
[     CACHE]: stored under: /tmp/.apt-proxy._apt
[  TEST-URL]: URL: http://packages.microsoft.com/repos/code/dists/stable/InRelease
[     AVAHI]: get cache entries for _apt_proxy._tcp
[     AVAHI]: get non-cache entries for _apt_proxy._tcp
[     CHECK]: Checking found proxy (http://192.168.0.27:3142) with testurl (http://packages.microsoft.com/repos/code/dists/stable/InRelease)
Service[ER][apt-cacher-ng proxy on squid-deb-proxy]@http://192.168.0.27:3142 
[     CHECK]: Checking found proxy (http://192.168.0.27:8000) with testurl (http://packages.microsoft.com/repos/code/dists/stable/InRelease)
[     CACHE]: Store (http://192.168.0.27:8000) in cache file (/tmp/.apt-proxy._apt)
Service[OK][Squid deb proxy on squid-deb-proxy]@http://192.168.0.27:8000 
[     PROXY]: return http://192.168.0.27:8000
[      INFO]: apt-proxy-detect
[     CACHE]: stored under: /tmp/.apt-proxy._apt
[  TEST-URL]: URL: http://download.proxmox.com/debian/pve/dists/bookworm/InRelease
[     CHECK]: Checking cached proxy (http://192.168.0.27:8000) with testurl (http://download.proxmox.com/debian/pve/dists/bookworm/InRelease)
[     WORKS]: give back cached proxy
[     PROXY]: return http://192.168.0.27:8000
[      INFO]: apt-proxy-detect
[     CACHE]: stored under: /tmp/.apt-proxy._apt
[  TEST-URL]: URL: http://local-repo.fritz.box/local-repo/dists/trunk/InRelease
[     CHECK]: Checking cached proxy (http://192.168.0.27:8000) with testurl (http://local-repo.fritz.box/local-repo/dists/trunk/InRelease)
[     WORKS]: give back cached proxy
[     PROXY]: return http://192.168.0.27:8000
[      INFO]: apt-proxy-detect
[     CACHE]: stored under: /tmp/.apt-proxy._apt
[  TEST-URL]: URL: http://security.debian.org/debian-security/dists/bookworm-security/InRelease
[     CHECK]: Checking cached proxy (http://192.168.0.27:8000) with testurl (http://security.debian.org/debian-security/dists/bookworm-security/InRelease)
[     WORKS]: give back cached proxy
[     PROXY]: return http://192.168.0.27:8000
[      INFO]: apt-proxy-detect
[     CACHE]: stored under: /tmp/.apt-proxy._apt
[  TEST-URL]: URL: http://deb.debian.org/debian/dists/bookworm/InRelease
[     CHECK]: Checking cached proxy (http://192.168.0.27:8000) with testurl (http://deb.debian.org/debian/dists/bookworm/InRelease)
[     WORKS]: give back cached proxy
[     PROXY]: return http://192.168.0.27:8000
Hit:1 http://local-repo.fritz.box/local-repo trunk InRelease
Hit:2 http://deb.debian.org/debian bookworm InRelease                                     
Hit:3 http://security.debian.org/debian-security bookworm-security InRelease              
Hit:4 http://download.proxmox.com/debian/pve bookworm InRelease                                                    
Hit:5 http://deb.debian.org/debian bookworm-updates InRelease                                                      
Hit:6 http://packages.microsoft.com/repos/code stable InRelease                              
Hit:7 https://dl.google.com/linux/chrome/deb stable InRelease         
Reading package lists... Done                   
Building dependency tree... Done
Reading state information... Done
22 packages can be upgraded. Run 'apt list --upgradable' to see them.

```
