#/bin/bash
NONE='\033[00m'
RED='\033[01;31m'
GREEN='\033[01;32m'
YELLOW='\033[01;33m'
PURPLE='\033[01;35m'
CYAN='\033[01;36m'
WHITE='\033[01;37m'
BOLD='\033[1m'
UNDERLINE='\033[4m'

coinGithubLink=https://github.com/oryxian/oryxcoin-resources/releases/download/1.0.1/oryxcoin-linux-cli-1-0-1.tar.gz
coinGithubLinkName=oryxcoin-linux-cli-1-0-1.tar.gz
coinPort=5757
coinRpc=5000
coinDaemon=oryxcoind
coinCli=oryxcoin-cli
coinTx=oryxcoin-tx
baseCoinCore=.oryxcoin
coinConfigFile=oryxcoin.conf
MAX=10

getIp() {
    echo -e "${BOLD}Resolving VPS Ip Address${NONE}"

    #Get ip
    mnip=$(curl --silent ipinfo.io/ip)

    #Attempt 3 more time to get the ip
    ipRegex="^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$"
    if ! [[ $mnip =~ $ipRegex ]] ; then
        echo
        echo "Could not resolve VPS Ip Address. Retrying"

        maxAttempts=3
        for (( c=1; c <= maxAttempts; c++ ));
        do
            sleep 5

            mnip=$(curl --silent ipinfo.io/ip)

            if [[ $mnip =~ $ipRegex ]] ; then
                break;
            else
                echo -e "${RED}* Attempt ${c} failed.${NONE}";
            fi
        done
    fi

    #Ask manually for ip
    if ! [[ $mnip =~ $ipRegex ]] ; then
        echo
        maxAttempts=3
        for (( c=0; c < maxAttempts; c++ ));
        do
            read -e -p "Input your ip manually (example ip format 123.123.123.123) :" mnip

            if [[ $mnip =~ $ipRegex ]] ; then
                break
            else
                echo -e "${RED}* The IP Address doesn't respect the required format.${NONE}";
            fi
        done
    fi

    #Ask manually for ip
    if ! [[ $mnip =~ $ipRegex ]] ; then
        echo
        echo -e "${RED}Could not resolve VPS Ip Address. Exiting${NONE}"
        exit 0;
    fi

    echo && echo -e "${GREEN}* Done. Your VPS Ip Address is ${mnip}.${NONE}";
}

askForNumberOfMasternodes() {
    existingNumberOfMasternodes=$(($(alias | grep "${coinDaemon}" | wc -l) + 0));

    echo -e "${BOLD}"
    read -e -p "You currently have ${existingNumberOfMasternodes} masternodes installed. How many masternodes do you want to install? (Default value is 1 masternodes) [1] :" numberOfMasternodes
    echo -e "${NONE}"

    re='^[0-9]+$'
    if ! [[ $numberOfMasternodes =~ $re ]] ; then
       numberOfMasternodes=1
    fi

    portArray=()
    rpcArray=()
    daemonArray=()
    cliArray=()
    txArray=()
    coreArray=()

    mnStart=$((existingNumberOfMasternodes + 1))
    mntotal=$((existingNumberOfMasternodes + numberOfMasternodes))
    for (( c=mnStart; c <= mntotal; c++ ));
    do
        tempPort=$((coinPort + (c - 1)))
        tempRpc=$((coinRpc + (c + 100)))
        tempDaemon="$coinDaemon$c"
        tempCli="$coinCli$c"
        tempTx="$coinTx$c"
        tempCore="$baseCoinCore$c"

        portArray+=($tempPort);
        rpcArray+=($tempRpc);
        daemonArray+=($tempDaemon);
        cliArray+=($tempCli);
        txArray+=($tempTx);
        coreArray+=($tempCore);
    done
}

checkForUbuntuVersion() {
   echo "[1/${MAX}] Checking Ubuntu version..."
    if [[ `cat /etc/issue.net`  == *16.04* ]]; then
        echo -e "${GREEN}* You are running `cat /etc/issue.net` . Setup will continue.${NONE}";
    else
        echo -e "${RED}* You are not running Ubuntu 16.04.X. You are running `cat /etc/issue.net` ${NONE}";
        echo && echo "Installation cancelled" && echo;
        exit;
    fi
}

updateAndUpgrade() {
    echo
    echo "[2/${MAX}] Runing update and upgrade. Please wait..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq -y > /dev/null 2>&1
    sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq > /dev/null 2>&1
    echo -e "${GREEN}* Done${NONE}";
}

setupSwap() {
    echo -e "${BOLD}"
    read -e -p "Add swap space? (Recommended for VPS that have 1GB of RAM) [Y/n] :" add_swap
    if [[ ("$add_swap" == "y" || "$add_swap" == "Y" || "$add_swap" == "") ]]; then
        swap_size="4G"
    else
        echo -e "${NONE}[3/${MAX}] Swap space not created."
    fi

    if [[ ("$add_swap" == "y" || "$add_swap" == "Y" || "$add_swap" == "") ]]; then
        echo && echo -e "${NONE}[3/${MAX}] Adding swap space...${YELLOW}"
        sudo fallocate -l $swap_size /swapfile
        sleep 2
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
        sudo swapon /swapfile
        echo -e "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab > /dev/null 2>&1
        sudo sysctl vm.swappiness=10
        sudo sysctl vm.vfs_cache_pressure=50
        echo -e "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf > /dev/null 2>&1
        echo -e "vm.vfs_cache_pressure=50" | sudo tee -a /etc/sysctl.conf > /dev/null 2>&1
        echo -e "${NONE}${GREEN}* Done${NONE}";
    fi
}

installFail2Ban() {
    echo
    echo -e "[4/${MAX}] Installing fail2ban. Please wait..."
    sudo apt-get -y install fail2ban > /dev/null 2>&1
    sudo systemctl enable fail2ban > /dev/null 2>&1
    sudo systemctl start fail2ban > /dev/null 2>&1
    echo -e "${NONE}${GREEN}* Done${NONE}";
}

installFirewall() {
    echo
    echo -e "[5/${MAX}] Installing UFW. Please wait..."
    sudo apt-get -y install ufw > /dev/null 2>&1
    sudo ufw allow OpenSSH > /dev/null 2>&1

    for (( c=0; c < numberOfMasternodes; c++ )) ;
    do
        sudo ufw allow "${portArray[c]}/tcp" > /dev/null 2>&1
    done

    echo "y" | sudo ufw enable > /dev/null 2>&1
    echo -e "${NONE}${GREEN}* Done${NONE}";
}

installDependencies() {
    echo
    echo -e "[6/${MAX}] Installing dependecies. Please wait..."
    sudo apt-get install git nano wget curl software-properties-common -qq -y > /dev/null 2>&1
    sudo add-apt-repository ppa:bitcoin/bitcoin -y > /dev/null 2>&1
    sudo apt-get update -qq -y > /dev/null 2>&1
    sudo apt-get install build-essential libtool autotools-dev pkg-config libssl-dev -qq -y > /dev/null 2>&1
    sudo apt-get install libboost-all-dev -qq -y > /dev/null 2>&1
    sudo apt-get install libevent-dev -qq -y > /dev/null 2>&1
    sudo apt-get install libminiupnpc-dev -qq -y > /dev/null 2>&1
    sudo apt-get install autoconf -qq -y > /dev/null 2>&1
    sudo apt-get install automake -qq -y > /dev/null 2>&1
    sudo apt-get install libdb4.8-dev libdb4.8++-dev -qq -y > /dev/null 2>&1
    sudo apt-get install libzmq3-dev -qq -y > /dev/null 2>&1
    echo -e "${NONE}${GREEN}* Done${NONE}";
}

downloadWallet() {
    echo
    echo -e "[7/${MAX}] Compiling wallet. Please wait, this might take a while to complete..."

    cd && mkdir new && cd new

    wget $coinGithubLink  > /dev/null 2>&1
    tar -xzf $coinGithubLinkName  > /dev/null 2>&1

    echo -e "${NONE}${GREEN}* Done${NONE}";
}

installWallet() {
    echo
    echo -e "[8/${MAX}] Installing wallet. Please wait..."
    strip $coinDaemon  > /dev/null 2>&1
    strip $coinCli  > /dev/null 2>&1
    strip $coinTx  > /dev/null 2>&1

    for (( c=0; c < numberOfMasternodes; c++ )) ;
    do
        cp $coinDaemon ${daemonArray[c]} > /dev/null 2>&1
        chmod 755 ${daemonArray[c]} > /dev/null 2>&1
        sudo mv ${daemonArray[c]} /usr/bin  > /dev/null 2>&1

        cp $coinCli ${cliArray[c]} > /dev/null 2>&1
        chmod 755 ${cliArray[c]} > /dev/null 2>&1
        sudo mv ${cliArray[c]} /usr/bin  > /dev/null 2>&1

        cp $coinTx ${txArray[c]} > /dev/null 2>&1
        chmod 755 ${txArray[c]} > /dev/null 2>&1
        sudo mv ${txArray[c]} /usr/bin  > /dev/null 2>&1
    done

    cd && sudo rm -rf new > /dev/null 2>&1
    cd
    echo -e "${NONE}${GREEN}* Done${NONE}";
}

configureWallet() {
    echo
    echo -e "[9/${MAX}] Configuring wallet. Please wait..."

    rpcuser='eGgwcFbVX0z6eGgwcFbVX0z6'
    rpcpass='f4dsoD6cbqdbf4dsoD6cbqdb'
    masternodePrivateKeyArray=()

    for (( c=0; c < numberOfMasternodes; c++ )) ;
    do
        cd
        mkdir ${coreArray[c]}
        cd ${coreArray[c]}
        touch $coinConfigFile
        chmod 755 $coinConfigFile
        cd

        echo -e "rpcuser=${rpcuser}\nrpcpassword=${rpcpass}\nrpcport=${rpcArray[c]}\nrpcallowedip=127.0.0.1\nport=${portArray[c]}" > ~/${coreArray[c]}/$coinConfigFile

        ${daemonArray[c]} -datadir="$(pwd)/${coreArray[c]}" -daemon > /dev/null 2>&1
        sleep 5

        mnkey=$(${cliArray[c]} -datadir="$(pwd)/${coreArray[c]}" masternode genkey)
        masternodePrivateKeyArray+=($mnkey)

        ${cliArray[c]} -datadir="$(pwd)/${coreArray[c]}" stop > /dev/null 2>&1

        sleep 5

        echo -e "rpcuser=${rpcuser}\nrpcpassword=${rpcpass}\nrpcport=${rpcArray[c]}\nrpcallowedip=127.0.0.1\nmasternode=1\ndaemon=1\nbind=${mnip}:${portArray[c]}\nmasternodeprivkey=${mnkey}" > ~/${coreArray[c]}/$coinConfigFile
    done

    echo -e "${NONE}${GREEN}* Done${NONE}";
}

startWallet() {
    echo
    echo -e "[10/${MAX}] Starting wallet daemon..."

    for (( c=0; c < numberOfMasternodes; c++ )) ;
    do
        ${daemonArray[c]} -datadir="$(pwd)/${coreArray[c]}" > /dev/null 2>&1
        (crontab -l ; echo "@reboot ${daemonArray[c]} -datadir="$(pwd)/${coreArray[c]}" -daemon > /dev/null 2>&1")| crontab -

        tempDaemonAliasName="${daemonArray[c]}"
        tempDaemonAliasCommand="${daemonArray[c]} -datadir=$(pwd)/${coreArray[c]}"

        echo -e "alias $tempDaemonAliasName=\"$tempDaemonAliasCommand\"" | sudo tee -a ~/.bashrc > /dev/null 2>&1

    	tempCliAliasName="${cliArray[c]}"
        tempCliAliasCommand="${cliArray[c]} -datadir=$(pwd)/${coreArray[c]}"

        echo -e "alias $tempCliAliasName=\"$tempCliAliasCommand\"" | sudo tee -a ~/.bashrc > /dev/null 2>&1

        tempTxAliasName="${txArray[c]}"
        tempTxAliasCommand="${txArray[c]} -datadir=$(pwd)/${coreArray[c]}"

        echo -e "alias $tempTxAliasName=\"$tempTxAliasCommand\"" | sudo tee -a ~/.bashrc > /dev/null 2>&1

        sleep 5
    done

    source ~/.bashrc  > /dev/null 2>&1

    echo -e "${GREEN}* Done${NONE}";
}

clear
cd

echo
echo -e "${YELLOW}**********************************************************************${NONE}"
echo -e "${YELLOW}*                                                                    *${NONE}"
echo -e "${YELLOW}*    ${NONE}${BOLD}This script will install and configure your OryxCoin masternode.${NONE}${YELLOW}   *${NONE}"
echo -e "${YELLOW}*                                                                    *${NONE}"
echo -e "${YELLOW}**********************************************************************${NONE}"
echo && echo

echo -e "${BOLD}"
read -p "This script will setup your OryxCoin Masternodes. Do you wish to continue? (y/n)?" response
echo -e "${NONE}"

if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
    getIp
    askForNumberOfMasternodes
    checkForUbuntuVersion
    updateAndUpgrade
    setupSwap
    installFail2Ban
    installFirewall
    installDependencies
    downloadWallet
    installWallet
    configureWallet
    startWallet

    echo && echo -e "${BOLD}The VPS side of your masternode has been installed. Save the masternode ip and private key so you can use them to complete your local wallet part of the setup${NONE}".

    for (( c=0; c < numberOfMasternodes; c++ )) ;
    do
        echo && echo -e "Masternode $((c + 1 + existingNumberOfMasternodes))";
        echo && echo -e "${BOLD}Daemon:${NONE} ${daemonArray[c]}";
        echo && echo -e "${BOLD}Cli:${NONE} ${cliArray[c]}";
        echo && echo -e "${BOLD}Tx:${NONE} ${txArray[c]}";
        echo && echo -e "${BOLD}Core Folder:${NONE} ${coreArray[c]}";
    	echo && echo -e "${BOLD}Masternode Config Line:${NONE} masternode$((c + 1 + existingNumberOfMasternodes)) ${mnip}:${portArray[c]} ${masternodePrivateKeyArray[c]} TX INDEX"
        echo
    done

    echo && echo -e "${BOLD}Continue with the cold wallet part of the setup${NONE}" && echo
    exec bash
else
    echo && echo "Installation cancelled" && echo
fi
