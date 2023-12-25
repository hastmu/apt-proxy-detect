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

What do you get?
- [X] detect via avahi
- [X] caching of URL specific working proxy (or none if none works)
- [X] caching over reboot if possible

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
- BRANCH [main]
- set permissions to a+rx
- create/updating /etc/apt/apt.conf.d/30apt-proxy-detect.conf

```

if you like to specify a branch do it like:
```
curl -s https://raw.githubusercontent.com/hastmu/apt-proxy-detect/main/install.sh  | sudo BRANCH=main bash
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

The found (via avahi-browse _apt_proxy._tcp) proxies are cached in case this has the 
wrong owner it is ignored and a waring is issued.

Thats it. Enjoy.

# Caching found proxies.
Latest version include the capability to cache the found proxies persistent over reboot.
Default locations per user in this order (in case this is not writable fall back to the next):
- _apt: /var/lib/apt/lists/auxfiles/
- *: $HOME/.config/
- *: /tmp/

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
# INFO-TAG       MS : MESSAGE
[        INFO][   2]: ===--- apt-proxy-detect ---===
[    TEST-URL][  16]: URL:  http://packages.microsoft.com/repos/code/dists/stable/InRelease
[        HASH][  25]: HASH: c0b917f192fa7cccb3f536f2c01b824d of (http://packages.microsoft.com)
[       CACHE][  30]: using stored under: /var/lib/apt/lists/auxfiles/.apt-proxy-detect._apt
[   CACHE-AGE][  33]: age: 687 sec
[ CHECK-PROXY][  35]: Checking proxy (http://192.168.0.27:8000) with testurl (http://packages.microsoft.com/repos/code/dists/stable/InRelease)
[       WORKS][ 127]: give back cached proxy
[       PROXY][ 131]: return http://192.168.0.27:8000
[        INFO][   3]: ===--- apt-proxy-detect ---===
[    TEST-URL][  20]: URL:  http://download.proxmox.com/debian/pve/dists/bookworm/InRelease
[        HASH][  34]: HASH: 17b43db99b56eb6355d41861f4f304d0 of (http://download.proxmox.com)
[       CACHE][  41]: using stored under: /var/lib/apt/lists/auxfiles/.apt-proxy-detect._apt
[   CACHE-AGE][  44]: age: 687 sec
[ CHECK-PROXY][  47]: Checking proxy (http://192.168.0.27:8000) with testurl (http://download.proxmox.com/debian/pve/dists/bookworm/InRelease)
[       WORKS][ 461]: give back cached proxy
[       PROXY][ 464]: return http://192.168.0.27:8000
[        INFO][   3]: ===--- apt-proxy-detect ---===
[    TEST-URL][  17]: URL:  http://local-repo.fritz.box/local-repo/dists/trunk/InRelease
[        HASH][  25]: HASH: 2bfbb1335aaf9d333a5c9498226eb208 of (http://local-repo.fritz.box)
[       CACHE][  32]: using stored under: /var/lib/apt/lists/auxfiles/.apt-proxy-detect._apt
[   CACHE-AGE][  37]: age: 687 sec
[ CHECK-PROXY][  39]: Checking proxy (http://192.168.0.27:8000) with testurl (http://local-repo.fritz.box/local-repo/dists/trunk/InRelease)
[       WORKS][  57]: give back cached proxy
[       PROXY][  60]: return http://192.168.0.27:8000
[        INFO][   2]: ===--- apt-proxy-detect ---===
[    TEST-URL][  19]: URL:  http://security.debian.org/debian-security/dists/bookworm-security/InRelease
[        HASH][  28]: HASH: 3b68f7b6590a2da8625ff71f01d38ffb of (http://security.debian.org)
[       CACHE][  36]: using stored under: /var/lib/apt/lists/auxfiles/.apt-proxy-detect._apt
[   CACHE-AGE][  39]: age: 688 sec
[ CHECK-PROXY][  41]: Checking proxy (http://192.168.0.27:8000) with testurl (http://security.debian.org/debian-security/dists/bookworm-security/InRelease)
[       WORKS][  93]: give back cached proxy
[       PROXY][  95]: return http://192.168.0.27:8000
[        INFO][   2]: ===--- apt-proxy-detect ---===
[    TEST-URL][  24]: URL:  http://deb.debian.org/debian/dists/bookworm/InRelease
[        HASH][  33]: HASH: efbfa0e2acaaa513c457b6698de83118 of (http://deb.debian.org)
[       CACHE][  41]: using stored under: /var/lib/apt/lists/auxfiles/.apt-proxy-detect._apt
[   CACHE-AGE][  44]: age: 687 sec
[ CHECK-PROXY][  47]: Checking proxy (http://192.168.0.27:8000) with testurl (http://deb.debian.org/debian/dists/bookworm/InRelease)
[       WORKS][ 145]: give back cached proxy
[       PROXY][ 147]: return http://192.168.0.27:8000
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
