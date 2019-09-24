#!/bin/bash
###########################################################################
# Define Variables                                                        #
###########################################################################

PREDIR=/var/tmp
STAGEDIR=/var/tmp/rtl8821ce
DRIVERSRC="https://github.com/tomaspinho/rtl8821ce"
PKGLIST="openssl kernel-devel perl mokutil keyutils dkms"
CHKPKGS=$(printf "$PKGLIST" | sed -e "s/ /-\[0-9\]\|\^/g")
CHKPKGS="^$CHKPKGS-[0-9]"
CONFFILE=/etc/x509.conf
PUBLICKEYFILE=/etc/x509.public.der
PRIVATEKEYFILE=/etc/x509.private.der
DRIVERMODULE=8821ce
MODULEPATH=/lib/modules/$(uname -r)/extra
BUSADDRESS=$(lspci | grep -i $DRIVERMODULE | awk '{ print $1 }')


###########################################################################
# Install required software, if not already installed.                    #
###########################################################################

printf "\nChecking if required software is installed ...\n"
if [ $(rpm -qa | grep -iE "$CHKPKGS" | wc -l) -eq 6 ]
then
   printf "Required software is installed.\n\n"
else
   printf "Required software is not installed.  Proceeding with install ...\n\n"
   dnf -y install $PKGLIST
   RC=$?
   if [ $RC -eq 0 ]
   then
      printf "Required software installed successfully ... proceeding ... \n\n"
   else
      printf "ERROR:  Required software was not installed successfully.\n"
      printf "        Please investigate.\n\n"
      exit
   fi
fi


###########################################################################
# Install git software, if not already installed.                         #
###########################################################################

printf "Checking to see if the git packages are installed ...\n"
if [ -f /bin/git ]
then
   printf "The git packages are already installed ... Proceeding.\n\n"
else
   printf "The git packages are not installed.  Proceeding with install.\n\n"
   dnf -y install git
   RC=$?
   if [ $RC -eq 0 ]
   then
      printf "The git packages have been installed successfully.\n\n"
   else
      printf "ERROR:  The git packages were not successfully installed.\n"
      printf "        Please investigate.\n\n"
      exit
   fi
fi

###########################################################################
# Download Driver Source, if not already downloaded.                      #
###########################################################################

printf "Checking if RTL8821CE driver source code is downloaded ...\n"
if [ -f $STAGEDIR/rtl8821c.mk ]
then
   printf "RTL8821CE driver source code is already downloaded.\n\n"
else
   printf "RTL8821CE driver source code is not downloaded yet ... Proceeding.\n\n"
   cd $PREDIR
   git clone $DRIVERSRC
   RC=$?
   if [ $RC -eq 0 ]
   then
      printf "RTL8821CE driver source code successfully downloaded.\n\n"
   else
      printf "ERROR:  RTL8821CE driver source code was not downloaded successfully.\n"
      printf "        Please investigate\n\n"
      exit
   fi
fi
cd $STAGEDIR
chmod +x *.sh


###########################################################################
# Create OpenSSL configuration file & Keys, if not already done.          #
###########################################################################

printf "Checking if openssl configuration file exists.\n"
if [ -f "$CONFFILE" ]
then
   printf "The openssl configuration file already exists. Proceeding ...\n"
else
   printf "The openssl configuration file doesn't exist.\n"
   printf "Collecting information for creation.\n\n"
   read -p "Please enter your name or the name of your organization:  " ORG
   read -p "Please enter your computer name:  " CNAME
   read -p "Please enter your email address:  " EMAIL
   printf "\nCreating openssl configuration file & keys.\n"
printf "[ req ]
default_bits = 4096
distinguished_name = req_distinguished_name
prompt = no
string_mask = utf8only
x509_extensions = myexts

[ req_distinguished_name ]
O = \"$ORG\"
CN = \"$CNAME\"
emailAddress = \"$EMAIL\"

[ myexts ]
basicConstraints=critical,CA:FALSE
keyUsage=digitalSignature
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid
" > $CONFFILE
fi


###########################################################################
# Create public & private x509 key pairs, if not already done.            #
###########################################################################

printf "Checking to see if x509 private & public key pairs exist.\n"
if [[ -f $PRIVATEKEYFILE ]] && [[ -f $PUBLICKEYFILE ]]
then
   printf "The x509 private & public key pairs exist.  Proceeding ...\n\n"
else
   printf "Creating the x509 private & public key pairs.\n\n"
   openssl req -x509 -new -nodes -utf8 -sha256 -days 36500 -batch -config $CONFFILE -outform DER -out $PUBLICKEYFILE -keyout $PRIVATEKEYFILE
   RC=$?
   if [ $RC -eq 0 ]
   then
      printf "The x509 private & public key pairs were created successfully.  Proceeding ...\n\n"
   else
      printf "ERROR:  The x509 private & public key paris were not successfully created.\n"
      printf "        Please investigate.\n\n"
      exit
   fi
fi


###########################################################################
# Compile the rtl8821ce driver.                                           #
###########################################################################
if [ -f "$STAGEDIR/$DRIVERMODULE.ko" ]
then
   printf "Driver module is already compiled.\n\n"
else
   printf "Compiling RTL8821CE driver module\n"
   make M=$STAGEDIR
fi


###########################################################################
# Sign the rtl8821ce driver wih the private & public key pair.            #
###########################################################################

if [ "x$EMAIL" == "x" ]
then
   EMAIL=$(grep -i emailaddress $CONFFILE | awk -F'"' '{ print $2 }')
fi
if [ $(strings $DRIVERMODULE.ko | grep -i $EMAIL | wc -l ) -gt 0 ]
then
   printf "Driver Module $DRIVERMODULE is already signed.\n\n"
else
   /usr/src/kernels/$(uname -r)/scripts/sign-file sha256 $PRIVATEKEYFILE $PUBLICKEYFILE $STAGEDIR/$DRIVERMODULE.ko
   if [ -f "$STAGEDIR/DRIVERMODULE.ko" ]
   then
      xz -z $STAGEDIR/$DRIVERMODULE.ko
   fi
   cp -p $STAGEDIR/$DRIVERMODULE.ko.xz $MODULEPATH
   if [ $(modinfo $DRIVERMODULE | grep -i signer | wc -l ) -gt 0 ]
   then
      printf "Driver Module $DRIVERMODULE has been successfully signed.\n\n"
   fi
fi


###########################################################################
# Load the newly signed RTL8821CE driver.                                 #
###########################################################################

printf "\nLoading the RTL8821CE driver.\n"
if [ $(ls -l /sys/class/net | grep -i "$BUSADDRESS" | wc -l) -eq 0 ]
then
   modprobe $DRIVERMODULE
fi
if [ $(ls -l /sys/class/net | grep -i "$BUSADDRESS" | wc -l) -gt 0 ]
then
   printf "\nThe RTL8821CE driver has been successfully loaded.\n\n"
else
   printf "ERROR:  The RTL8821CE driver has not loaded successfully.\n"
   printf "        This may be caused by the public key not yet being\n"
   printf "        enrolled.  Once the public key enrollment has been\n"
   printf "        completed, run this script again.\n\n"
fi


###########################################################################
# Enroll public key on target system, if not already enrolled.            #
###########################################################################

if [ "x$EMAIL" == "x" ]
then
   EMAIL=$(grep -i emailaddress $CONFFILE | awk -F'"' '{ print $2 }')
fi
if [ $(mokutil --list-enrolled | grep -i $EMAIL | wc -l) -gt 0 ]
then
   printf "Public key has been enrolled.  Proceeding ...\n\n"
else
   printf "Public key has not been enrolled.  Please note that this will\n"
   printf "require you to enter a password 3 times: 2 for the import\n"
   printf "process \& 1 for the enrollment.  Checking if public key has\n"
   printf "been imported ...\n"
   if [ $(mokutil --list-new 2>&1 | grep -i $EMAIL | wc -l) -gt 1 ]
   then
      printf "Public key has been successfully imported.\n\n"
   else
      printf "Public key has not been imported yet.  Importing ...\n"
      mokutil --import $PUBLICKEYFILE
      if [ $(mokutil --list-new | grep -i $EMAIL | wc -l) -gt 1 ]
      then
         printf "\nPublic key was imported successfully.  Reboot is required.\n"
         printf "Once the reboot is done, the system will come up with a\n"
         printf "prompt that says """Press any key to perform MOK management."""\n"
         printf "Press the Enter key before the countdown expires.\n"
         printf "On the Perform MOK Management screen, select Enroll MOK.\n"
         printf "Select continue \& then select yes.  You will be prompted\n"
         printf "to enter a password.  It should be the same password entered\n"
         printf "during the import process.\n"
      else
         printf "ERROR:  The public key was not imported successfully.\n"
         printf "        Please run this script again to retry the import.\n\n"
      fi
   fi
fi

