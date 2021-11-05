#!/bin/sh

#使用说明
#该脚本支持常见的linux内核的系统
#请将该脚本放置需要进行预检查的服务器上并执行，脚本会检测基本的操作系统信息，并通过控制台回显检测结果
#使用者可以根据返回结果自行整改或者参考脚本返回的整改命令行进行整改

check_key() {
    result=$($1 2>/dev/null)

    if [ -n "$result" ]; then
        echo $result >>log
    fi
}

check_shadow() {
    for i in $(cat /etc/shadow | awk -F ":" '{print $1":"$2}'); do
        pas=$(echo $i | awk -F ":" '{print $2}')
        if [ "$pas" = "*" ] || [ "$pas" = "!!" ] || [ "$pas" = "*LOCK*" ] || [[ "$pas" =~ "!" ]]; then
		    echo 'a' > /dev/null
	    else
    		echo $i | awk -F ":" '{print $1}' >> log
        fi
    done
}

check_rootlogin(){
    result=`cat /etc/ssh/sshd_config | grep PermitRootLogin| grep -Ev '^$|^#' | awk '{print $2}'`
    if [ "$result" == "yes" ] ; then
            echo "PermitRootLogin is yes" >> log
        fi   
}

check_tmpfiles(){
    result=$($1 2>/dev/null)

    if [ -n "$result" ]; then
        echo "/tmp/$result" >>log
    fi   
}

check_otherfiles(){
    result=$($1 2>/dev/null)

    if [ -n "$result" ]; then
        echo $result >>log
    fi      
}

create_outputs(){
    declare -i Bnum
    declare -i Enum
    declare -i nums
    Bnum=$(cat log |grep -n $1 | cut -d: -f1)
    Enum=$(cat log |grep -n $2 | cut -d: -f1)
    nums=$(($Enum-$Bnum))
	
    if [ "$nums" == "1" ] ; then
        result='ok'
    else
        result=`cat log | grep -A $nums $1 | awk 'NR>1' | grep -v $2`
    fi   
}

>log
result=""

echo -e "\033[34m ---------------------------------START SCAN------------------------------- \033[0m"

echo "check_key_begin" >>log
check_key "ls /etc/ssh/*_key"
check_key "ls /etc/ssh/*_key.pub"
check_key "ls /root/.ssh/authorized_keys"
for i in $(ls /home/); do
    check_key "ls /home/$i/.ssh/authorized_keys"
done
b=''
for ((i = 0; $i <= 100; i += 2)); do
    printf "check key file:   [%-50s]%d%%\r" $b $i
    sleep 0.01
    b==$b
done
echo "check_key_end" >>log


echo "check_shadow_begin" >>log
check_shadow
echo -e ""
c=''
for ((i = 0; $i <= 100; i += 2)); do
    printf "check shadow file:[%-50s]%d%%\r" $c $i
    sleep 0.01
    c==$c
done
echo "check_shadow_end" >>log

echo "check_rootlogin_begin" >>log
check_rootlogin
echo -e ""
c=''
for ((i = 0; $i <= 100; i += 2)); do
    printf "check root login: [%-50s]%d%%\r" $c $i
    sleep 0.01
    c==$c
done
echo "check_rootlogin_end" >>log

echo "check_tmpfiles_begin" >>log
check_tmpfiles "ls /tmp*"
for i in $(ls /home/); do
    check_otherfiles "ls /home/$i/*"
done
echo -e ""
c=''
for ((i = 0; $i <= 100; i += 2)); do
    printf "check tmp files:  [%-50s]%d%%\r" $c $i
    sleep 0.01
    c==$c
done
echo "check_tmpfiles_end" >>log

echo -e ""
echo -e "\033[34m ---------------------------------END SCAN------------------------------- \033[0m"

sleep 2

echo "###################################OUTPUTS#################################"  > outputs.log
echo -e "\033[34m ###################################OUTPUTS################################# \033[0m"

echo "##########################Key###########################"  >> outputs.log
echo -e "\033[35m #############################Key############################# \033[0m"
sleep 1
create_outputs check_key_begin check_key_end
    if [ "$result" == "ok" ] ; then
        echo "Check key is ok!" >> outputs.log
        echo -e "\033[32m Check key is ok! \033[0m"
    else
        echo "Check key is fail!" >> outputs.log
        echo -e '\033[31m Check key is fail! \033[0m'
        echo "The list key files must be deleted:" >> outputs.log
        echo -e '\033[31m The list key files must be deleted: \033[0m'
        echo $result | sed 's/ /\n/g' >> outputs.log
        echo $result | sed 's/ /\n/g'
        echo -e "\033[36m You can use the list commands to resolve the fail. \033[0m"
        for i in $result
        do
            echo -e "rm -rf $i"
        done
    fi  

sleep 1
echo "##########################Password###########################" >> outputs.log
echo -e "\033[35m ###########################Password########################### \033[0m"
sleep 1
create_outputs check_shadow_begin check_shadow_end
    if [ "$result" == "ok" ] ; then
        echo "Check password is ok!" >> outputs.log
        echo -e "\033[32m Check password is ok! \033[0m"
    else
        echo "Check password is fail!" >> outputs.log
        echo -e '\033[31m Check password is fail! \033[0m'
        echo "The list users password must be disabled:" >> outputs.log
        echo -e '\033[31m The list users password must be disabled: \033[0m'
        echo $result | sed 's/ /\n/g' >> outputs.log
        echo $result | sed 's/ /\n/g'
        echo -e "\033[36m You can use the list commands to resolve the fail. \033[0m"
        for i in $result
        do
            echo -e "passwd -l $i"
        done

    fi  

sleep 1
echo "###########################Loging############################" >> outputs.log
echo -e "\033[35m ############################Loging############################ \033[0m"
sleep 1
create_outputs check_rootlogin_begin check_rootlogin_end
    if [ "$result" == "ok" ] ; then
        echo "Check login is ok!" >> outputs.log
        echo -e "\033[32m Check login is ok! \033[0m"
    else
        echo "Check login is fail!" >> outputs.log
        echo -e '\033[31m Check login is fail! \033[0m'
        echo "PermitRootLogin must be disabled." >> outputs.log
        echo -e '\033[31m PermitRootLogin must be disabled. \033[0m'
        echo $result | sed 's/ /\n/g' >> outputs.log
        echo $result | sed 's/ /\n/g' 
        echo -e "\033[36m You can use the list commands to resolve the fail. \033[0m"
        echo -e "sed -i s/'PermitRootLogin yes'/'#PermitRootLogin yes'/ /etc/ssh/sshd_config"
    fi  

sleep 1
echo "##########################Tempfiles###########################" >> outputs.log
echo -e "\033[35m ##########################Tempfiles########################## \033[0m"
sleep 1
create_outputs check_tmpfiles_begin check_tmpfiles_end
    if [ "$result" == "ok" ] ; then
        echo "Check tempfiles is ok!" >> outputs.log
        echo -e "\033[32m Check tempfiles is ok! \033[0m"
    else
        echo "Check tempfiles is warning!" >> outputs.log
        echo -e "\033[33m Check tempfiles is warning! \033[0m"
        echo "The list files may be the tempfiles:" >> outputs.log
        echo -e "\033[33m The list files may be the tempfiles: \033[0m"
        echo $result | sed 's/ /\n/g' >> outputs.log
        echo $result | sed 's/ /\n/g'
        echo -e "\033[36m You can use the list commands to resolve the warning. \033[0m"
        for i in $result
        do
            echo -e "rm -rf $i"
        done
    fi 
sleep 1
echo -e "\033[34m ###################################END################################# \033[0m"
echo -e "You can see the outputs in the outputs.log."