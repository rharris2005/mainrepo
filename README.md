# Main Repository.

I'm stuffing tools in here that you may find handy for a variety of reasons.  There isn't much yet but that may change.

The first thing I've loaded is rtl8821ce.sh.  It does everything that is needed to download the wireless network driver source for the Realtek rtl8821ce NIC from https://github.com/tomaspinho/rtl8821ce.  The script should work on any Fedora based distribution of version 30 or higher.  It may work on earlier distributions but has not been tested on those.  It installs the required software to compile & sign the driver for systems using secure boot.  It then compiles it, signs it after creating the openssl public & private key pair.  I'm currently working on getting it to the point where it will also automatically re-compile the driver when a new kernel version is installed & booted.
