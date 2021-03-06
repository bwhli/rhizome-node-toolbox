#Declare functions used in script.
formatDisk(){
	echo -e "${YELLOW}Below are the disks attached to your system.${NC}"
	echo
	lsblk -d -o NAME,SIZE,MOUNTPOINT
	echo
	echo -e "${YELLOW}Which disk would you like to format and mount? (e.g. sdb)${NC}"
	read DEVICE_ID
	echo -e "${YELLOW}What is the directory where you want to mount $DEVICE_ID to? (e.g. /mnt/disks/data1)${NC}"
	read MOUNT_POINT
	echo
	echo -e "${YELLOW}Is the information below correct? (1 for yes, 2 for no.)${NC}"
	echo "DEVICE ID: $DEVICE_ID"
	echo "MOUNT POINT: $MOUNT_POINT"
	echo
	select yn in "Yes" "No"; do
	    case $yn in
	        Yes )
				#If user answers "Yes", move on to formatDiskProcess().
				formatDiskProcess;
				break;;
	        No )
				#If user answers "No", rerun formatDisk().
				formatDisk;
				break;;
	    esac
	done
}

formatDiskProcess() {
	#Check if disk is already formatted. The format set for this check is ext4.
	if [[ $(lsblk -no FSTYPE /dev/$DEVICE_ID) = ext4 ]];
	then
		#If disk is already formatted, alert user and return to main menu.
        echo "This disk is already formatted."
        echo "Returning to main menu..."
        sleep 2
        rhizomeToolbox
	else
		mkfs.ext4 -m 0 -F -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/$DEVICE_ID
		mkdir -p $MOUNT_POINT
		mount -o discard,defaults /dev/$DEVICE_ID $MOUNT_POINT
		chmod -R a=r,a+X,u+w $MOUNT_POINT
		chown root:root -R $MOUNT_POINT
		cp /etc/fstab /etc/fstab.backup
		echo UUID=`blkid -s UUID -o value /dev/$DEVICE_ID` $MOUNT_POINT ext4 discard,defaults,nofail 0 2 | tee -a /etc/fstab
	fi
	returnMainMenu
}

installNodeDependencies() {
	#Install dependencies for citizen node.
	apt-get update
	apt-get install  -y systemd apt-transport-https ca-certificates curl gnupg-agent software-properties-common
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
	add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
	apt-get update
	apt-get -y install docker-ce docker-ce-cli containerd.io
	usermod -aG docker $(whoami)
	systemctl enable docker.service
	systemctl start docker.service
	apt-get install -y python-pip
	pip install docker-compose
}

installHAProxy() {
	#Install HAProxy
	apt-get update
	apt-get install -y haproxy
	systemctl enable haproxy.service
	systemctl start haproxy.service
	rm -rf /etc/haproxy/haproxy.cfg
	curl -o /etc/haproxy/haproxy.cfg https://raw.githubusercontent.com/rhizomeicx/rhizome-node-toolbox/master/prep/haproxy.cfg > /dev/null 2>&1
	curl -o /etc/haproxy/whitelist.lst https://raw.githubusercontent.com/rhizomeicx/rhizome-node-toolbox/master/misc/whitelist.lst > /dev/null 2>&1
	touch /etc/haproxy/monitoring-whitelist.lst
	echo "127.0.0.1" >> /etc/haproxy/monitoring-whitelist.lst
	service haproxy reload
	if [ -f /home/icon/citizen/docker-compose.yml ]; then
		curl -o /home/icon/citizen/docker-compose_haproxy.yml https://raw.githubusercontent.com/rhizomeicx/rhizome-node-toolbox/master/citizen/default/docker-compose_haproxy.yml > /dev/null 2>&1
		chmod 700 /home/icon/citizen/docker-compose_haproxy.yml
		chown icon:icon /home/icon/citizen/docker-compose_haproxy.yml
	fi

	#Start P-Rep node if docker-compose.yml is detected.
	if [ -f /home/icon/prep/docker-compose.yml ]; then
		curl -o /home/icon/prep/docker-compose_haproxy.yml https://raw.githubusercontent.com/rhizomeicx/rhizome-node-toolbox/master/prep/default/docker-compose_haproxy.yml > /dev/null 2>&1
		chmod 700 /home/icon/prep/docker-compose_haproxy.yml
		chown icon:icon /home/icon/prep/docker-compose_haproxy.yml
	fi
	echo -e "${YELLOW}In order for HAProxy to function correctly, the following edits have to be made to your docker-compose.yml file."
	echo -e "- network_mode: host should be removed."
	echo -e "- 7100:7100 should be changed to \"127.0.0.2:7200:7100\""
	echo -e "- 7100:7100 should be changed to \"127.0.0.2:9100:9000\""
	echo
	echo -e "For your convenience, a pre-configured file has been downloaded to /home/icon/citizen/docker-compose_haproxy.yml. If needed, please add your keystore and keystore password to this file, replace your original docker-compose.yml, and run \"docker-compose up -d\"."
	echo
	echo -e "This HAProxy configuration includes a rate limit and IP whitelist feature. The rate limit settings can be found at /etc/haproxy/haproxy.cfg. The IP whitelist can be found at /etc/haproxy/whitelist.lst."
	echo
	echo -e "This HAProxy configuration includes a monitoring page, which can be accessed at http://YOUR-IP:8404/stats/. The IP whitelist for monitoring can be found at /etc/haproxy/monitoring-whitelist.lst. Please add your whitelisted IPs to this file to access the stats page.${NC}"
	returnMainMenu
}

installCitizenNode(){
	echo
	echo -e "${YELLOW}In order to proceed, please select an installation mode."
	echo -e "- Easy mode will create an icon user, and install the citizen node in /home/icon/citizen."
	echo -e "- Advanced mode allows you to specify the installation path.${NC}"
	echo
	select opt in "Easy" "Advanced"; do
	    case $opt in
	        Easy )
					createICONUser;
					installCitizenNodeEasy;
					break;;
	        Advanced )
					createICONUser;
					installCitizenNodeAdvanced;
					break;;
	    esac
	done
}

installCitizenNodeEasy(){
	#Install citizen node dependencies.
	installNodeDependencies
	#Create directory for citizen node.
	mkdir -p /home/icon/citizen
	##Download docker-compose.yml.
	curl -o /home/icon/citizen/docker-compose.yml https://raw.githubusercontent.com/rhizomeicx/rhizome-node-toolbox/master/citizen/default/docker-compose.yml > /dev/null 2>&1
	#Download rc.local.
	curl -o /etc/rc.local https://raw.githubusercontent.com/rhizomeicx/rhizome-node-toolbox/master/scripts/rc.local > /dev/null 2>&1
	chmod +x /etc/rc.local
	#Permissions reset
	chmod -R a=r,a+X,u+w /home/icon
	chown icon:icon -R /home/icon
	chmod -R a=r,a+X,u+w /home/icon/citizen
	chmod 700 /home/icon/citizen/docker-compose.yml
	chown icon:icon -R /home/icon/citizen
	#Add icon to docker group.
	usermod -aG docker icon
	#START DOCKER IMAGE
	cd /home/icon/citizen && docker-compose up -d
	sleep 2
	echo "Installation is finished!"
	echo "Returning to main menu..."
	sleep 2
	rhizomeToolbox
}

installCitizenNodeAdvanced(){
	echo -e "${YELLOW}What directory would you like to install the ICON citizen node to? (e.g. /mnt/disks/data1/citizen)${NC}"
	read CTZ_INSTALL_DIR
	#Install citizen node dependencies.
	installNodeDependencies
	#Create directory for citizen node.
	mkdir -p $CTZ_INSTALL_DIR
	ln -s $CTZ_INSTALL_DIR /home/icon
	##Download docker-compose.yml.
	curl -o $CTZ_INSTALL_DIR/docker-compose.yml https://raw.githubusercontent.com/rhizomeicx/rhizome-node-toolbox/master/citizen/default/docker-compose.yml > /dev/null 2>&1
	#Download rc.local.
	curl -o /etc/rc.local https://raw.githubusercontent.com/rhizomeicx/rhizome-node-toolbox/master/scripts/rc.local > /dev/null 2>&1
	chmod +x /etc/rc.local
	#Permissions reset
	chmod -R a=r,a+X,u+w /home/icon
	chown icon:icon -R /home/icon
	chmod -R a=r,a+X,u+w $CTZ_INSTALL_DIR
	chmod 700 $CTZ_INSTALL_DIR/docker-compose.yml
	chown icon:icon -R $CTZ_INSTALL_DIR
	#Add icon to docker group.
	usermod -aG docker icon
	#START DOCKER IMAGE
	cd $CTZ_INSTALL_DIR && docker-compose up -d
	sleep 2
	echo "Installation is finished!"
	echo "Returning to main menu..."
	sleep 2
	rhizomeToolbox
}

installPRepNode(){
	echo
	echo -e "${YELLOW}In order to proceed, please select an installation mode."
	echo -e "- Easy mode will create an icon user, and install the P-Rep node in /home/icon/prep."
	echo -e "- Advanced mode allows you to specify the installation path.${NC}"
	echo
	select opt in "Easy" "Advanced"; do
	    case $opt in
	        Easy )
				createICONUser;
				installPRepNodeEasy;
				break;;
	        Advanced )
				createICONUser;
				installPRepNodeAdvanced;
				break;;
	    esac
	done
}

installPRepNodeEasy(){
	#Install P-Rep dependencies.
	installNodeDependencies
	#Create directory for P-Rep node.
	mkdir -p /home/icon/prep
	#Create /cert folder and keystore file.
	mkdir -p /home/icon/prep/cert
	touch /home/icon/prep/cert/keystore
	##Download docker-compose.yml.
	curl -o /home/icon/prep/docker-compose.yml https://raw.githubusercontent.com/rhizomeicx/rhizome-node-toolbox/master/prep/docker-compose.yml > /dev/null 2>&1
	#Download rc.local.
	curl -o /etc/rc.local https://raw.githubusercontent.com/rhizomeicx/rhizome-node-toolbox/master/scripts/rc.local > /dev/null 2>&1
	chmod +x /etc/rc.local
	#Permissions reset
	chmod -R a=r,a+X,u+w /home/icon
	chown icon:icon -R /home/icon
	chmod -R a=r,a+X,u+w /home/icon/prep
	chmod 700 /home/icon/prep/docker-compose.yml
	chown icon:icon -R /home/icon/prep
	#Add icon to docker group.
	usermod -aG docker icon
	#START DOCKER IMAGE
	#cd /home/icon/prep && docker-compose up -d
	sleep 2
	echo "Installation is finished!"
	sleep 2
	echo "Please add keystore file and password to docker-compose.yml and start the Docker image with docker-compose up -d."
	returnMainMenu
}

installPRepNodeAdvanced(){
	echo -e "${YELLOW}What directory would you like to install the ICON P-Rep node to? (e.g. /mnt/disks/data1/prep)${NC}"
	read PREP_INSTALL_DIR
	#Install P-Rep node dependencies.
	installNodeDependencies
	#Create directory for P-Rep node.
	mkdir -p $PREP_INSTALL_DIR
	#Create /cert folder and keystore file.
	mkdir -p $PREP_INSTALL_DIR/cert
	touch $PREP_INSTALL_DIR/cert/keystore
	#Make symlink to home folder of "icon" user.
	ln -s $PREP_INSTALL_DIR /home/icon
	#Download rc.local.
	curl -o /etc/rc.local https://raw.githubusercontent.com/rhizomeicx/rhizome-node-toolbox/master/scripts/rc.local > /dev/null 2>&1
	chmod +x /etc/rc.local
	#Download docker-compose.yml.
	curl -o $PREP_INSTALL_DIR/docker-compose.yml https://raw.githubusercontent.com/rhizomeicx/rhizome-node-toolbox/master/prep/docker-compose.yml > /dev/null 2>&1
	#Permissions reset
	chmod -R a=r,a+X,u+w /home/icon
	chown icon:icon -R /home/icon
	chmod -R a=r,a+X,u+w $PREP_INSTALL_DIR
	chmod 700 $PREP_INSTALL_DIR/docker-compose.yml
	chmod 700 $PREP_INSTALL_DIR/cert/keystore
	chown icon:icon -R $PREP_INSTALL_DIR
	#Add icon to docker group.
	usermod -aG docker icon
	#START DOCKER IMAGE
	#cd PREP_INSTALL_DIR && docker-compose up -d
	sleep 2
	echo "Installation is finished!"
	sleep 2
	echo "Please add keystore file and password to docker-compose.yml and start the Docker image."
	returnMainMenu
}

createICONUser(){
	#Declare icon user and create random password.
	ICONPASSWORD=$(</dev/urandom tr -dc _A-Z-a-z-0-9 | head -c12)
	ICONUSERNAME="icon"
	#Check if icon user already exists.
	if id -u "$ICONUSERNAME" >/dev/null 2>&1; then
	    echo "This user already exists."
	#Create icon user if it doesn't exist.
	else
	    useradd -m -p $ICONPASSWORD -s /bin/bash $ICONUSERNAME
	    usermod -a -G sudo $ICONUSERNAME
	    echo $ICONUSERNAME:$ICONPASSWORD | chpasswd
	    confirmUserPassword;
	fi
}

confirmUserPassword(){
	#Confirm user has stored password.
	echo "The icon user has been created successfully."
	echo -e "${RED}Username: icon${NC}"
	echo -e "${RED}Password: $ICONPASSWORD${NC}"
	echo
	read -p "Please store the login credentials above in a secure location, and type kbbq to continue."$'\n' -n 4 -r
	echo
	if [[ $REPLY =~ ^kbbq$ ]]
	then
		return
   	else
    		confirmUserPassword
	fi
}

installStackdriver(){
	curl -sSO https://dl.google.com/cloudagents/install-logging-agent.sh
	bash install-logging-agent.sh
	curl -sSO https://dl.google.com/cloudagents/install-monitoring-agent.sh
	sudo bash install-monitoring-agent.sh
	rm -rf install-logging-agent.sh
	rm -rf install-monitoring-agent.sh
	returnMainMenu
}

returnMainMenu(){
	sleep 2
	echo "Returning to main menu..."
	sleep 2
	rhizomeToolbox
}

rhizomeToolbox() {
echo
echo -e "${YELLOW}RHIZOME Toolbox v0.2${NC}"
echo
PS3=$'\n''RHIZOME Toolbox v0.2> '
options=("Format and Mount Disk" "Install Citizen Node" "Install P-Rep Node" "Install HAProxy" "Install Google Stackdriver" "Quit")
select opt in "${options[@]}"
do
    case $opt in
        "Format and Mount Disk")
            formatDisk;
            break;;
        "Install Citizen Node")
						installNodeDependencies;
            installCitizenNode;
            break;;
        "Install P-Rep Node")
            installNodeDependencies;
            installPRepNode;
            break;;
				"Install HAProxy")
						installHAProxy;
						break;;
				"Install Google Stackdriver")
						installStackdriver;
						break;;
        "Quit")
            break;;
        *) echo "invalid option $REPLY";;
    esac
done
}

#Global color declarations.
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

#Run the script!
rhizomeToolbox
