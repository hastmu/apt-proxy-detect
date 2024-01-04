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
- [X] Proxy detection via
    - avahi
    - set defaults
- [X] caching of URL specific working proxy (or none if none works)
- [X] caching over reboot if possible
- [X] allow mixture of allowed and non allowed urls (no need for direct declaration)

# How does it look?

Example output:
```
dev@dev:~$ apt-proxy-detect.sh 

usage: apt-proxy-detect.sh <defaults|set-default|url for proxy>

 defaults                        ... list default proxies
 set-default <proxy1>,<proxy2>   ... set default proxies
 url for proxy                   ... this is the url a proxy is tested for

```

or with setting default proxies:
```
dev@dev:~$ apt-proxy-detect.sh set-default https://192.168.0.2:8093,https://192.168.0.3:4544,http://192.168.0.27:8000
defining default proxies...
proxy: https://192.168.0.2:8093
proxy: https://192.168.0.3:4544
proxy: http://192.168.0.27:8000
saved.
```

or show default proxies:
```
dev@dev:~$ apt-proxy-detect.sh defaults
proxy: https://192.168.0.2:8093
proxy: https://192.168.0.3:4544
proxy: http://192.168.0.27:8000
```

or with specific url for checking (failing+avahi detection):
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

Required packages can be installed via:
```
sudo apt install -y coreutils grep sed wget avahi-utils
```

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

In case of issues you can set "DEBUG_APT_PROXY_DETECT" to get all details, like e.g.:
```
export DEBUG_APT_PROXY_DETECT=1
sudo apt update
```

looks like (first run, with comments)

```
dev@dev:~$ export DEBUG_APT_PROXY_DETECT=1
dev@dev:~$ sudo apt update
# INFO-TAG       MS : MESSAGE
[        INFO][   2]: ===--- apt-proxy-detect ---===
[    TEST-URL][  18]: URL:  http://packages.microsoft.com/repos/code/dists/stable/InRelease
[        HASH][  42]: HASH: c0b917f192fa7cccb3f536f2c01b824d of (http://packages.microsoft.com)

# no proxy known so search one...
[       AVAHI][  52]: get cache entries for _apt_proxy._tcp
[       CHECK][ 110]: Checking found proxy (http://192.168.0.27:8000) with testurl (http://packages.microsoft.com/repos/code/dists/stable/InRelease)
[ CHECK-PROXY][ 150]: Proxy (http://192.168.0.27:8000) works with testurl (http://packages.microsoft.com/repos/code/dists/stable/InRelease).

# register working proxy
[         ADD][ 161]: add proxy to working proxy list.

# first proxy does work for url
Service[OK][Squid deb proxy on squid-deb-proxy]@http://192.168.0.27:8000 
[       CHECK][ 209]: Checking found proxy (http://192.168.0.27:3142) with testurl (http://packages.microsoft.com/repos/code/dists/stable/InRelease)
[ CHECK-PROXY][ 220]: Proxy (http://192.168.0.27:3142) failed with testurl (http://packages.microsoft.com/repos/code/dists/stable/InRelease)

# second proxy does not work for the url
Service[ER][apt-cacher-ng proxy on squid-deb-proxy]@http://192.168.0.27:3142 
[       PROXY][ 223]: return :http://192.168.0.27:8000:
[       CACHE][ 231]: Store (http://192.168.0.27:8000) in cache file (/var/lib/apt/lists/auxfiles/.apt-proxy-detect._apt)
[       CACHE][ 235]: Update cachefile.
[        INFO][   1]: ===--- apt-proxy-detect ---===
[    TEST-URL][  18]: URL:  http://download.proxmox.com/debian/pve/dists/bookworm/InRelease
[        HASH][  34]: HASH: 17b43db99b56eb6355d41861f4f304d0 of (http://download.proxmox.com)
[       CACHE][  39]: using stored under: /var/lib/apt/lists/auxfiles/.apt-proxy-detect._apt

# check if the once working proxy if fine
[       CHECK][  44]: once working proxy: http://192.168.0.27:8000 for http://download.proxmox.com/debian/pve/dists/bookworm/InRelease
[ CHECK-PROXY][  70]: Proxy (http://192.168.0.27:8000) works with testurl (http://download.proxmox.com/debian/pve/dists/bookworm/InRelease).

# it is so no need to search again.
[       PROXY][  72]: return :http://192.168.0.27:8000:
[       CACHE][  75]: Store (http://192.168.0.27:8000) in cache file (/var/lib/apt/lists/auxfiles/.apt-proxy-detect._apt)
[       CACHE][  77]: Update cachefile.
[        INFO][   1]: ===--- apt-proxy-detect ---===
[    TEST-URL][  16]: URL:  http://local-repo.fritz.box/local-repo/dists/trunk/InRelease
[        HASH][  24]: HASH: 2bfbb1335aaf9d333a5c9498226eb208 of (http://local-repo.fritz.box)
[       CACHE][  29]: using stored under: /var/lib/apt/lists/auxfiles/.apt-proxy-detect._apt
[       CHECK][  31]: once working proxy: http://192.168.0.27:8000 for http://local-repo.fritz.box/local-repo/dists/trunk/InRelease

# once working proxy failed
[ CHECK-PROXY][  41]: Proxy (http://192.168.0.27:8000) failed with testurl (http://local-repo.fritz.box/local-repo/dists/trunk/InRelease)

# search again
[       AVAHI][  46]: get cache entries for _apt_proxy._tcp
[       CHECK][  91]: Checking found proxy (http://192.168.0.27:8000) with testurl (http://local-repo.fritz.box/local-repo/dists/trunk/InRelease)
[ CHECK-PROXY][ 101]: Proxy (http://192.168.0.27:8000) failed with testurl (http://local-repo.fritz.box/local-repo/dists/trunk/InRelease)
Service[ER][Squid deb proxy on squid-deb-proxy]@http://192.168.0.27:8000 
[       CHECK][ 124]: Checking found proxy (http://192.168.0.27:3142) with testurl (http://local-repo.fritz.box/local-repo/dists/trunk/InRelease)
[ CHECK-PROXY][ 134]: Proxy (http://192.168.0.27:3142) failed with testurl (http://local-repo.fritz.box/local-repo/dists/trunk/InRelease)
Service[ER][apt-cacher-ng proxy on squid-deb-proxy]@http://192.168.0.27:3142 

# none found (as local repos are not allowed on the proxies)
[       PROXY][ 149]: return ::
[       CACHE][ 152]: Store (NONE) in cache file (/var/lib/apt/lists/auxfiles/.apt-proxy-detect._apt)
[       CACHE][ 154]: Update cachefile.
[        INFO][   2]: ===--- apt-proxy-detect ---===
[    TEST-URL][  26]: URL:  http://security.debian.org/debian-security/dists/bookworm-security/InRelease
[        HASH][  41]: HASH: 3b68f7b6590a2da8625ff71f01d38ffb of (http://security.debian.org)
[       CACHE][  47]: using stored under: /var/lib/apt/lists/auxfiles/.apt-proxy-detect._apt
[       CHECK][  50]: once working proxy: http://192.168.0.27:8000 for http://security.debian.org/debian-security/dists/bookworm-security/InRelease
[ CHECK-PROXY][  61]: Proxy (http://192.168.0.27:8000) works with testurl (http://security.debian.org/debian-security/dists/bookworm-security/InRelease).
[       PROXY][  64]: return :http://192.168.0.27:8000:
[       CACHE][  66]: Store (http://192.168.0.27:8000) in cache file (/var/lib/apt/lists/auxfiles/.apt-proxy-detect._apt)
[       CACHE][  70]: Update cachefile.
[        INFO][   2]: ===--- apt-proxy-detect ---===
[    TEST-URL][  19]: URL:  http://deb.debian.org/debian/dists/bookworm/InRelease
[        HASH][  27]: HASH: efbfa0e2acaaa513c457b6698de83118 of (http://deb.debian.org)
[       CACHE][  31]: using stored under: /var/lib/apt/lists/auxfiles/.apt-proxy-detect._apt
[       CHECK][  34]: once working proxy: http://192.168.0.27:8000 for http://deb.debian.org/debian/dists/bookworm/InRelease
[ CHECK-PROXY][  45]: Proxy (http://192.168.0.27:8000) works with testurl (http://deb.debian.org/debian/dists/bookworm/InRelease).
[       PROXY][  48]: return :http://192.168.0.27:8000:
[       CACHE][  51]: Store (http://192.168.0.27:8000) in cache file (/var/lib/apt/lists/auxfiles/.apt-proxy-detect._apt)
[       CACHE][  53]: Update cachefile.
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
[    TEST-URL][  13]: URL:  http://packages.microsoft.com/repos/code/dists/stable/InRelease
[        HASH][  31]: HASH: c0b917f192fa7cccb3f536f2c01b824d of (http://packages.microsoft.com)
[       CACHE][  37]: using stored under: /var/lib/apt/lists/auxfiles/.apt-proxy-detect._apt
[   CACHE-AGE][  41]: age: 57 sec
[ CHECK-PROXY][ 129]: Proxy (http://192.168.0.27:8000) works with testurl (http://packages.microsoft.com/repos/code/dists/stable/InRelease).
[       WORKS][ 132]: give back cached proxy
[       PROXY][ 134]: return http://192.168.0.27:8000
[        INFO][   2]: ===--- apt-proxy-detect ---===
[    TEST-URL][  17]: URL:  http://download.proxmox.com/debian/pve/dists/bookworm/InRelease
[        HASH][  25]: HASH: 17b43db99b56eb6355d41861f4f304d0 of (http://download.proxmox.com)
[       CACHE][  30]: using stored under: /var/lib/apt/lists/auxfiles/.apt-proxy-detect._apt
[   CACHE-AGE][  32]: age: 57 sec
[ CHECK-PROXY][ 243]: Proxy (http://192.168.0.27:8000) works with testurl (http://download.proxmox.com/debian/pve/dists/bookworm/InRelease).
[       WORKS][ 246]: give back cached proxy
[       PROXY][ 249]: return http://192.168.0.27:8000
[        INFO][   2]: ===--- apt-proxy-detect ---===
[    TEST-URL][  16]: URL:  http://local-repo.fritz.box/local-repo/dists/trunk/InRelease
[        HASH][  24]: HASH: 2bfbb1335aaf9d333a5c9498226eb208 of (http://local-repo.fritz.box)
[       CACHE][  37]: using stored under: /var/lib/apt/lists/auxfiles/.apt-proxy-detect._apt
[   CACHE-AGE][  39]: age: 58 sec
[ CHECK-PROXY][  41]: NONE-cached
[       WORKS][  43]: give back cached proxy
[       PROXY][  48]: return NONE
[        INFO][   2]: ===--- apt-proxy-detect ---===
[    TEST-URL][  17]: URL:  http://security.debian.org/debian-security/dists/bookworm-security/InRelease
[        HASH][  25]: HASH: 3b68f7b6590a2da8625ff71f01d38ffb of (http://security.debian.org)
[       CACHE][  30]: using stored under: /var/lib/apt/lists/auxfiles/.apt-proxy-detect._apt
[   CACHE-AGE][  32]: age: 58 sec
[ CHECK-PROXY][  43]: Proxy (http://192.168.0.27:8000) works with testurl (http://security.debian.org/debian-security/dists/bookworm-security/InRelease).
[       WORKS][  45]: give back cached proxy
[       PROXY][  48]: return http://192.168.0.27:8000
[        INFO][   2]: ===--- apt-proxy-detect ---===
[    TEST-URL][  19]: URL:  http://deb.debian.org/debian/dists/bookworm/InRelease
[        HASH][  28]: HASH: efbfa0e2acaaa513c457b6698de83118 of (http://deb.debian.org)
[       CACHE][  36]: using stored under: /var/lib/apt/lists/auxfiles/.apt-proxy-detect._apt
[   CACHE-AGE][  46]: age: 58 sec
[ CHECK-PROXY][  99]: Proxy (http://192.168.0.27:8000) works with testurl (http://deb.debian.org/debian/dists/bookworm/InRelease).
[       WORKS][ 102]: give back cached proxy
[       PROXY][ 104]: return http://192.168.0.27:8000

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

looks like (with default proxies run)

```
dev@dev:~$ export DEBUG_APT_PROXY_DETECT=1
dev@dev:~$ sudo apt update
# INFO-TAG       MS : MESSAGE
[        INFO][   2]: ===--- apt-proxy-detect ---===
[    DEFAULTS][   5]: loaded from /usr/local/etc/apt-proxy-detect.bash
[    TEST-URL][  23]: URL:  http://packages.microsoft.com/repos/code/dists/stable/InRelease
[        HASH][  42]: HASH: c0b917f192fa7cccb3f536f2c01b824d of (http://packages.microsoft.com)

# first time - but introducing default proxies as once working
[       CHECK][  48]: once working proxy: https://192.168.0.2:8093 for http://packages.microsoft.com/repos/code/dists/stable/InRelease
[ CHECK-PROXY][  60]: Proxy (https://192.168.0.2:8093) failed with testurl (http://packages.microsoft.com/repos/code/dists/stable/InRelease)
[       CHECK][  66]: once working proxy: https://192.168.0.3:4544 for http://packages.microsoft.com/repos/code/dists/stable/InRelease
[ CHECK-PROXY][  80]: Proxy (https://192.168.0.3:4544) failed with testurl (http://packages.microsoft.com/repos/code/dists/stable/InRelease)
[       CHECK][  83]: once working proxy: http://192.168.0.27:8000 for http://packages.microsoft.com/repos/code/dists/stable/InRelease
[ CHECK-PROXY][ 124]: Proxy (http://192.168.0.27:8000) works with testurl (http://packages.microsoft.com/repos/code/dists/stable/InRelease).

# and one works.
[       PROXY][ 126]: return :http://192.168.0.27:8000:
[       CACHE][ 129]: Store (http://192.168.0.27:8000) in cache file (/var/lib/apt/lists/auxfiles/.apt-proxy-detect._apt)
[       CACHE][ 137]: Update cachefile.
[        INFO][   3]: ===--- apt-proxy-detect ---===
[    DEFAULTS][   6]: loaded from /usr/local/etc/apt-proxy-detect.bash
[    TEST-URL][  22]: URL:  http://download.proxmox.com/debian/pve/dists/bookworm/InRelease
[        HASH][  33]: HASH: 17b43db99b56eb6355d41861f4f304d0 of (http://download.proxmox.com)
[       CACHE][  39]: using stored under: /var/lib/apt/lists/auxfiles/.apt-proxy-detect._apt
[       CHECK][  43]: once working proxy: https://192.168.0.2:8093 for http://download.proxmox.com/debian/pve/dists/bookworm/InRelease
[ CHECK-PROXY][  54]: Proxy (https://192.168.0.2:8093) failed with testurl (http://download.proxmox.com/debian/pve/dists/bookworm/InRelease)
[       CHECK][  57]: once working proxy: https://192.168.0.3:4544 for http://download.proxmox.com/debian/pve/dists/bookworm/InRelease
[ CHECK-PROXY][  69]: Proxy (https://192.168.0.3:4544) failed with testurl (http://download.proxmox.com/debian/pve/dists/bookworm/InRelease)
[       CHECK][  73]: once working proxy: http://192.168.0.27:8000 for http://download.proxmox.com/debian/pve/dists/bookworm/InRelease
[ CHECK-PROXY][ 104]: Proxy (http://192.168.0.27:8000) works with testurl (http://download.proxmox.com/debian/pve/dists/bookworm/InRelease).
[       PROXY][ 107]: return :http://192.168.0.27:8000:
[       CACHE][ 111]: Store (http://192.168.0.27:8000) in cache file (/var/lib/apt/lists/auxfiles/.apt-proxy-detect._apt)
[       CACHE][ 114]: Update cachefile.
[        INFO][   2]: ===--- apt-proxy-detect ---===
[    DEFAULTS][   5]: loaded from /usr/local/etc/apt-proxy-detect.bash
[    TEST-URL][  29]: URL:  http://local-repo.fritz.box/local-repo/dists/trunk/InRelease
[        HASH][  78]: HASH: 2bfbb1335aaf9d333a5c9498226eb208 of (http://local-repo.fritz.box)
[       CACHE][  85]: using stored under: /var/lib/apt/lists/auxfiles/.apt-proxy-detect._apt

# first time - but introducing default proxies as once working
[       CHECK][  89]: once working proxy: https://192.168.0.2:8093 for http://local-repo.fritz.box/local-repo/dists/trunk/InRelease
[ CHECK-PROXY][ 101]: Proxy (https://192.168.0.2:8093) failed with testurl (http://local-repo.fritz.box/local-repo/dists/trunk/InRelease)
[       CHECK][ 105]: once working proxy: https://192.168.0.3:4544 for http://local-repo.fritz.box/local-repo/dists/trunk/InRelease
[ CHECK-PROXY][ 116]: Proxy (https://192.168.0.3:4544) failed with testurl (http://local-repo.fritz.box/local-repo/dists/trunk/InRelease)
[       CHECK][ 119]: once working proxy: http://192.168.0.27:8000 for http://local-repo.fritz.box/local-repo/dists/trunk/InRelease
[ CHECK-PROXY][ 141]: Proxy (http://192.168.0.27:8000) failed with testurl (http://local-repo.fritz.box/local-repo/dists/trunk/InRelease)

# non is working as this is a local repo
# search via AVAHI.
[       AVAHI][ 147]: get cache entries for _apt_proxy._tcp
[       CHECK][ 195]: Checking found proxy (http://192.168.0.27:8000) with testurl (http://local-repo.fritz.box/local-repo/dists/trunk/InRelease)
[ CHECK-PROXY][ 207]: Proxy (http://192.168.0.27:8000) failed with testurl (http://local-repo.fritz.box/local-repo/dists/trunk/InRelease)
Service[ER][Squid deb proxy on squid-deb-proxy]@http://192.168.0.27:8000 
[       CHECK][ 237]: Checking found proxy (http://192.168.0.27:3142) with testurl (http://local-repo.fritz.box/local-repo/dists/trunk/InRelease)
[ CHECK-PROXY][ 249]: Proxy (http://192.168.0.27:3142) failed with testurl (http://local-repo.fritz.box/local-repo/dists/trunk/InRelease)
Service[ER][apt-cacher-ng proxy on squid-deb-proxy]@http://192.168.0.27:3142 

# also the AVAHI found ones do not work -> so none (direct connect)
[       PROXY][ 252]: return ::
[       CACHE][ 259]: Store (NONE) in cache file (/var/lib/apt/lists/auxfiles/.apt-proxy-detect._apt)
[       CACHE][ 262]: Update cachefile.
[        INFO][   2]: ===--- apt-proxy-detect ---===
[    DEFAULTS][   6]: loaded from /usr/local/etc/apt-proxy-detect.bash
[    TEST-URL][  22]: URL:  http://security.debian.org/debian-security/dists/bookworm-security/InRelease
[        HASH][  32]: HASH: 3b68f7b6590a2da8625ff71f01d38ffb of (http://security.debian.org)
[       CACHE][  37]: using stored under: /var/lib/apt/lists/auxfiles/.apt-proxy-detect._apt
[       CHECK][  40]: once working proxy: https://192.168.0.2:8093 for http://security.debian.org/debian-security/dists/bookworm-security/InRelease
[ CHECK-PROXY][  50]: Proxy (https://192.168.0.2:8093) failed with testurl (http://security.debian.org/debian-security/dists/bookworm-security/InRelease)
[       CHECK][  53]: once working proxy: https://192.168.0.3:4544 for http://security.debian.org/debian-security/dists/bookworm-security/InRelease
[ CHECK-PROXY][  65]: Proxy (https://192.168.0.3:4544) failed with testurl (http://security.debian.org/debian-security/dists/bookworm-security/InRelease)
[       CHECK][  68]: once working proxy: http://192.168.0.27:8000 for http://security.debian.org/debian-security/dists/bookworm-security/InRelease
[ CHECK-PROXY][  96]: Proxy (http://192.168.0.27:8000) works with testurl (http://security.debian.org/debian-security/dists/bookworm-security/InRelease).
[       PROXY][  99]: return :http://192.168.0.27:8000:
[       CACHE][ 102]: Store (http://192.168.0.27:8000) in cache file (/var/lib/apt/lists/auxfiles/.apt-proxy-detect._apt)
[       CACHE][ 105]: Update cachefile.
[        INFO][   2]: ===--- apt-proxy-detect ---===
[    DEFAULTS][   4]: loaded from /usr/local/etc/apt-proxy-detect.bash
[    TEST-URL][  21]: URL:  http://deb.debian.org/debian/dists/bookworm/InRelease
[        HASH][  31]: HASH: efbfa0e2acaaa513c457b6698de83118 of (http://deb.debian.org)
[       CACHE][  37]: using stored under: /var/lib/apt/lists/auxfiles/.apt-proxy-detect._apt
[       CHECK][  39]: once working proxy: https://192.168.0.2:8093 for http://deb.debian.org/debian/dists/bookworm/InRelease
[ CHECK-PROXY][  50]: Proxy (https://192.168.0.2:8093) failed with testurl (http://deb.debian.org/debian/dists/bookworm/InRelease)
[       CHECK][  52]: once working proxy: https://192.168.0.3:4544 for http://deb.debian.org/debian/dists/bookworm/InRelease
[ CHECK-PROXY][  63]: Proxy (https://192.168.0.3:4544) failed with testurl (http://deb.debian.org/debian/dists/bookworm/InRelease)
[       CHECK][  66]: once working proxy: http://192.168.0.27:8000 for http://deb.debian.org/debian/dists/bookworm/InRelease
[ CHECK-PROXY][  94]: Proxy (http://192.168.0.27:8000) works with testurl (http://deb.debian.org/debian/dists/bookworm/InRelease).
[       PROXY][  97]: return :http://192.168.0.27:8000:
[       CACHE][ 101]: Store (http://192.168.0.27:8000) in cache file (/var/lib/apt/lists/auxfiles/.apt-proxy-detect._apt)
[       CACHE][ 105]: Update cachefile.

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
