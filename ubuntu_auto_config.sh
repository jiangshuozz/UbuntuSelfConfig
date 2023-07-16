#!/bin/bash

index=1

PrintTitle(){
  echo '\n--------------------------------------------'
  echo '\e[47;30m' $1:$2 '\e[0m'
  echo '--------------------------------------------'
}

# 设置时区
PrintTitle $index "Set TimeZone"
index=$((index+1))
sudo -E timedatectl set-timezone "Asia/Shanghai"
echo now: $(date)


# 设置允许root登录
PrintTitle $index "Set PermitRootLogin"
index=$((index+1))
grep  "PermitRootLogin yes" /etc/ssh/sshd_config
if [ $? -ne 0 ]; then
    echo "root login configuring..."
    sudo sed -i "/#PermitRootLogin prohibit-password/aPermitRootLogin yes" /etc/ssh/sshd_config
    echo "root login config done!"
else
    echo "root login already configured!"
fi

# sudo免密
PrintTitle $index "Set nopasswd for $(whoami)"
index=$((index+1))
current_user=$(whoami)
current_user_content="$(whoami).*NOPASSWD"
echo sudo grep  "$current_user_content" /etc/sudoers
sudo grep  "$current_user_content" /etc/sudoers
if [ $? -ne 0 ]; then
    # su - root -c "chmod +w /etc/sudoers;echo '$current_user ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers;chmod -w /etc/sudoers;"
    sudo sed -i "/# See sudoers(5) fo/i# sudo no passwd for user\r\n$current_user ALL=(ALL) NOPASSWD:ALL\r\n" /etc/sudoers
else
    echo "sudo nopassword already configured!"
fi


# 避免开机网络连接过久 sudo systemctl mask systemd-networkd-wait-online.service or
PrintTitle $index "Set Network timeout"
index=$((index+1))
network_online_file="/etc/systemd/system/network-online.target.wants/systemd-networkd-wait-online.service"
sudo grep  "TimeoutStartSec" $network_online_file
if [ $? -ne 0 ]; then
    sudo sed -i -e "/ExecStart.*online/aTimeoutStartSec=3sec" $network_online_file
else
    echo "network timeout already configured!"
fi

# 设置固定IP
PrintTitle $index "Set Fixed IP"
index=$((index+1))
ip_cfg_file="/etc/netplan/00-installer-config.yaml"
temp_file=temp.txt
echo current config:
cat $ip_cfg_file
read -p  "Set ip? Be careful, network will be affected (Y/n): " ack
case $ack in
Y | y | yes | YES)
    
    read -p "Input the ip (e.g. 192.168.1.10/24) :" ip
    read -p "Input the v4 gateway (e.g. 192.168.1.1) :" gateway
    if  [ ! -n "$ip" ] ;then
        echo "You have not input a ip! Config finished!"
    else
        echo "The ip you input is $ip"
        sudo echo "# This is the network config written by 'subiquity'" > $temp_file
        sudo echo "network:" >> $temp_file
        sudo echo "  ethernets:" >> $temp_file
        sudo echo "    eth0:" >> $temp_file
        sudo echo "      addresses:" >> $temp_file
        sudo echo "      - $ip" >> $temp_file
        #sudo echo "      dhcp6: true" >> $temp_file
        sudo echo "      nameservers:" >> $temp_file
        sudo echo "        search: []" >> $temp_file 
        sudo echo "        addresses:" >> $temp_file
        sudo echo "        - 114.114.114.114" >> $temp_file
        sudo echo "        - 8.8.8.8" >> $temp_file       
                
        if  [ ! -n "$gateway" ] ;then
            echo "You have not input a gateway! default!"
        else
            echo "The gateway you input is $gateway"
            sudo echo "        - $gateway" >> $temp_file
            echo "      routes:" >> $temp_file
            echo "      - to: default" >> $temp_file
            echo "        via: $gateway" >> $temp_file
        fi
        echo "" >> $temp_file
        echo "  version: 2" >> $temp_file
        cat $temp_file
        read -p "Sure to replace the old config? Any input to exit:" isCanceled
        if  [ ! -n "$isCanceled" ] ;then
            echo "Backup old and apply the new one!"
            sudo cp $ip_cfg_file $ip_cfg_file.bak
            sudo mv $temp_file $ip_cfg_file
            sudo chmod 644 $ip_cfg_file
            sudo netplan apply
        else
            echo "Config cannceled!"
        fi
        
    fi
    ;;

n | N | No | no | NO| *)

    echo "No need config."
    ;;
esac

PrintTitle $index "Config Done! Good luck to you!"
echo "\e[41;30m Notice: If Ip is set, please reboot. \e[0m"