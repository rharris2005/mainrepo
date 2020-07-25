# Main Repository.

I'm stuffing tools in here that you may find handy for a variety of reasons.  There isn't much yet but that may change.

The first thing I've loaded is rtl8821ce.sh.  It does everything that is needed to download the wireless network driver source for the Realtek rtl8821ce NIC from https://github.com/tomaspinho/rtl8821ce.  The script should work on any Fedora based distribution of version 30 or higher.  It may work on earlier distributions but has not been tested on those.  It installs the required software to compile & sign the driver for systems using secure boot.  It then compiles it, signs it after creating the openssl public & private key pair.  

Place the rtl8821ce.service file in /etc/systemd/system.  Then place the rtl8821ce file in /etc/init.d.  If you have SELinux enabled & configured in enforcing mode you will need to run the following commands to allow the service to run dkms-install.sh

     ausearch -c 'rtl8821ce.sh' --raw | audit2allow -M my-rtl8821cesh
     semodule -X 300 -i my-rtl8821cesh.pp
     systemctl enable rtl8821ce

Once the above commands have been run you should be good.  Whent the rtl8821ce service starts, it will run /etc/init.d/rtl8821ce which will check to see if /lib/moodules/$(uname -r)/extra/8821ce.ko.xz exists and also see if the module 8821ce is loaded.  If it is then it will exit clean.  If either condition fails, then it will run /var/tmp/mainrepo/rtl8821ce.sh which will check everything that has to be done to create the module & load it.
