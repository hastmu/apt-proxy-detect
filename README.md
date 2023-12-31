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
Latest version also cache the none-proxy state for 60 seconds, accepting the fact
that there is currently no proxy around which can serve the request.

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

looks like (first run)

```
dev@dev:~$ export DEBUG_APT_PROXY_DETECT=1
dev@dev:~$ sudo apt update
# INFO-TAG       MS : MESSAGE
[        INFO][   1]: ===--- apt-proxy-detect ---===
[    TEST-URL][  16]: URL:  http://packages.microsoft.com/repos/code/dists/stable/InRelease
[        HASH][  26]: HASH: c0b917f192fa7cccb3f536f2c01b824d of (http://packages.microsoft.com)
[       AVAHI][  33]: get cache entries for _apt_proxy._tcp
[       CHECK][ 208]: Checking found proxy (http://192.168.0.27:8000) with testurl (http://packages.microsoft.com/repos/code/dists/stable/InRelease)
[ CHECK-PROXY][ 331]: Proxy (http://192.168.0.27:8000) works with testurl (http://packages.microsoft.com/repos/code/dists/stable/InRelease).
[         ADD][ 333]: add proxy to working proxy list.
Service[OK][Squid deb proxy on squid-deb-proxy]@http://192.168.0.27:8000 
[       CHECK][ 356]: Checking found proxy (http://192.168.0.27:3142) with testurl (http://packages.microsoft.com/repos/code/dists/stable/InRelease)
[ CHECK-PROXY][ 367]: Proxy (http://192.168.0.27:3142) failed with testurl (http://packages.microsoft.com/repos/code/dists/stable/InRelease)
Service[ER][apt-cacher-ng proxy on squid-deb-proxy]@http://192.168.0.27:3142 
[       PROXY][ 370]: return :http://192.168.0.27:8000:
[       CACHE][ 373]: Store (http://192.168.0.27:8000) in cache file (/var/lib/apt/lists/auxfiles/.apt-proxy-detect._apt)
[       CACHE][ 375]: Update cachefile.
[        INFO][   2]: ===--- apt-proxy-detect ---===
[    TEST-URL][  17]: URL:  http://download.proxmox.com/debian/pve/dists/bookworm/InRelease
[        HASH][  29]: HASH: 17b43db99b56eb6355d41861f4f304d0 of (http://download.proxmox.com)
[       CACHE][  35]: using stored under: /var/lib/apt/lists/auxfiles/.apt-proxy-detect._apt
[       CHECK][  38]: once working proxy: http://192.168.0.27:8000 for http://download.proxmox.com/debian/pve/dists/bookworm/InRelease
[ CHECK-PROXY][ 141]: Proxy (http://192.168.0.27:8000) works with testurl (http://download.proxmox.com/debian/pve/dists/bookworm/InRelease).
[       PROXY][ 144]: return :http://192.168.0.27:8000:
[       CACHE][ 146]: Store (http://192.168.0.27:8000) in cache file (/var/lib/apt/lists/auxfiles/.apt-proxy-detect._apt)
[       CACHE][ 148]: Update cachefile.
[        INFO][   1]: ===--- apt-proxy-detect ---===
[    TEST-URL][  15]: URL:  http://local-repo.fritz.box/local-repo/dists/trunk/InRelease
[        HASH][  23]: HASH: 2bfbb1335aaf9d333a5c9498226eb208 of (http://local-repo.fritz.box)
[       CACHE][  28]: using stored under: /var/lib/apt/lists/auxfiles/.apt-proxy-detect._apt
[       CHECK][  30]: once working proxy: http://192.168.0.27:8000 for http://local-repo.fritz.box/local-repo/dists/trunk/InRelease
[ CHECK-PROXY][  49]: Proxy (http://192.168.0.27:8000) works with testurl (http://local-repo.fritz.box/local-repo/dists/trunk/InRelease).
[       PROXY][  51]: return :http://192.168.0.27:8000:
[       CACHE][  53]: Store (http://192.168.0.27:8000) in cache file (/var/lib/apt/lists/auxfiles/.apt-proxy-detect._apt)
[       CACHE][  56]: Update cachefile.
[        INFO][   1]: ===--- apt-proxy-detect ---===
[    TEST-URL][  27]: URL:  http://security.debian.org/debian-security/dists/bookworm-security/InRelease
[        HASH][  38]: HASH: 3b68f7b6590a2da8625ff71f01d38ffb of (http://security.debian.org)
[       CACHE][  47]: using stored under: /var/lib/apt/lists/auxfiles/.apt-proxy-detect._apt
[       CHECK][  51]: once working proxy: http://192.168.0.27:8000 for http://security.debian.org/debian-security/dists/bookworm-security/InRelease
[ CHECK-PROXY][ 102]: Proxy (http://192.168.0.27:8000) works with testurl (http://security.debian.org/debian-security/dists/bookworm-security/InRelease).
[       PROXY][ 104]: return :http://192.168.0.27:8000:
[       CACHE][ 106]: Store (http://192.168.0.27:8000) in cache file (/var/lib/apt/lists/auxfiles/.apt-proxy-detect._apt)
[       CACHE][ 108]: Update cachefile.
[        INFO][   1]: ===--- apt-proxy-detect ---===
[    TEST-URL][  16]: URL:  http://deb.debian.org/debian/dists/bookworm/InRelease
[        HASH][  24]: HASH: efbfa0e2acaaa513c457b6698de83118 of (http://deb.debian.org)
[       CACHE][  28]: using stored under: /var/lib/apt/lists/auxfiles/.apt-proxy-detect._apt
[       CHECK][  30]: once working proxy: http://192.168.0.27:8000 for http://deb.debian.org/debian/dists/bookworm/InRelease
[ CHECK-PROXY][  93]: Proxy (http://192.168.0.27:8000) works with testurl (http://deb.debian.org/debian/dists/bookworm/InRelease).
[       PROXY][  95]: return :http://192.168.0.27:8000:
[       CACHE][  97]: Store (http://192.168.0.27:8000) in cache file (/var/lib/apt/lists/auxfiles/.apt-proxy-detect._apt)
[       CACHE][ 100]: Update cachefile.
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

looks like (second run)

```
dev@dev:~$ export DEBUG_APT_PROXY_DETECT=1
dev@dev:~$ sudo apt update
# INFO-TAG       MS : MESSAGE
[        INFO][   1]: ===--- apt-proxy-detect ---===
[    TEST-URL][  15]: URL:  http://packages.microsoft.com/repos/code/dists/stable/InRelease
[        HASH][  23]: HASH: c0b917f192fa7cccb3f536f2c01b824d of (http://packages.microsoft.com)
[       CACHE][  28]: using stored under: /var/lib/apt/lists/auxfiles/.apt-proxy-detect._apt
[   CACHE-AGE][  30]: age: 110 sec
[ CHECK-PROXY][ 138]: Proxy (http://192.168.0.27:8000) works with testurl (http://packages.microsoft.com/repos/code/dists/stable/InRelease).
[       WORKS][ 140]: give back cached proxy
[       PROXY][ 142]: return http://192.168.0.27:8000
[        INFO][   1]: ===--- apt-proxy-detect ---===
[    TEST-URL][  16]: URL:  http://download.proxmox.com/debian/pve/dists/bookworm/InRelease
[        HASH][  23]: HASH: 17b43db99b56eb6355d41861f4f304d0 of (http://download.proxmox.com)
[       CACHE][  28]: using stored under: /var/lib/apt/lists/auxfiles/.apt-proxy-detect._apt
[   CACHE-AGE][  30]: age: 110 sec
[ CHECK-PROXY][ 134]: Proxy (http://192.168.0.27:8000) works with testurl (http://download.proxmox.com/debian/pve/dists/bookworm/InRelease).
[       WORKS][ 136]: give back cached proxy
[       PROXY][ 138]: return http://192.168.0.27:8000
[        INFO][   2]: ===--- apt-proxy-detect ---===
[    TEST-URL][  16]: URL:  http://local-repo.fritz.box/local-repo/dists/trunk/InRelease
[        HASH][  24]: HASH: 2bfbb1335aaf9d333a5c9498226eb208 of (http://local-repo.fritz.box)
[       CACHE][  28]: using stored under: /var/lib/apt/lists/auxfiles/.apt-proxy-detect._apt
[   CACHE-AGE][  30]: age: 111 sec
[ CHECK-PROXY][  49]: Proxy (http://192.168.0.27:8000) works with testurl (http://local-repo.fritz.box/local-repo/dists/trunk/InRelease).
[       WORKS][  52]: give back cached proxy
[       PROXY][  54]: return http://192.168.0.27:8000
[        INFO][   2]: ===--- apt-proxy-detect ---===
[    TEST-URL][  19]: URL:  http://security.debian.org/debian-security/dists/bookworm-security/InRelease
[        HASH][  27]: HASH: 3b68f7b6590a2da8625ff71f01d38ffb of (http://security.debian.org)
[       CACHE][  32]: using stored under: /var/lib/apt/lists/auxfiles/.apt-proxy-detect._apt
[   CACHE-AGE][  34]: age: 110 sec
[ CHECK-PROXY][  44]: Proxy (http://192.168.0.27:8000) works with testurl (http://security.debian.org/debian-security/dists/bookworm-security/InRelease).
[       WORKS][  48]: give back cached proxy
[       PROXY][  50]: return http://192.168.0.27:8000
[        INFO][   2]: ===--- apt-proxy-detect ---===
[    TEST-URL][  18]: URL:  http://deb.debian.org/debian/dists/bookworm/InRelease
[        HASH][  30]: HASH: efbfa0e2acaaa513c457b6698de83118 of (http://deb.debian.org)
[       CACHE][  34]: using stored under: /var/lib/apt/lists/auxfiles/.apt-proxy-detect._apt
[   CACHE-AGE][  37]: age: 110 sec
[ CHECK-PROXY][ 107]: Proxy (http://192.168.0.27:8000) works with testurl (http://deb.debian.org/debian/dists/bookworm/InRelease).
[       WORKS][ 110]: give back cached proxy
[       PROXY][ 112]: return http://192.168.0.27:8000
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
