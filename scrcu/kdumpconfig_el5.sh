#!/bin/bash

#########################################
#Function:    setup scrcu rhel kdump function
#Usage:       bash kdumpconfig_el5.sh
#Author:      Xiaochuan Wang
#Company:     SYSSSC
#Version:     1.0
#########################################

echo Kdump Helper is starting to configure kdump service

#kexec-tools checking
if ! rpm -q kexec-tools > /dev/null
then 
    echo "kexec-tools not found, please run command yum install kexec-tools to install it"
    exit 1
fi
mem_total=`free -g |awk 'NR==2 {print $2 }'`
echo Your total memory is $mem_total G

#backup grub.conf
grub_conf=/boot/grub/grub.conf
grub_conf_kdumphelper=/boot/grub/grub.conf.kdumphelper.$(date +%y-%m-%d-%H:%M:%S)
echo backup $grub_conf to $grub_conf_kdumphelper
cp $grub_conf $grub_conf_kdumphelper
#      RHEL5 crashkernel compute
#       crashkernel=memory@offset
#
#        +---------------------------------------+
#        | RAM       | crashkernel | crashkernel |
#        | size      | memory      | offset      |
#        |-----------+-------------+-------------|
#        |  0 - 2G   | 128M        | 16          |
#        | 2G - 6G   | 256M        | 24          |
#        | 6G - 8G   | 512M        | 16          |
#        | 8G - 24G  | 768M        | 32          |
#        +---------------------------------------+
#       */    
compute_rhel5_crash_kernel ()
{
    reserved_memory=128
    offset=16
    mem_size=$1
    if [ $mem_size -le 2 ] 
    then
        reserved_memory=128
        offset=16
    elif [ $mem_size -le 6 ]
    then 
        reserved_memory=256
        offset=24
    elif [ $mem_size -le 8 ]
    then
        reserved_memory=512
        offset=16
    else
        reserved_memory=768
        offset=32
    fi
    echo "$reserved_memory"M@"$offset"M
}
    crashkernel_para=`compute_rhel5_crash_kernel $mem_total `
echo crashkernel=$crashkernel_para is set in $grub_conf
grubby --update-kernel=DEFAULT --args=crashkernel=$crashkernel_para

#backup kdump.conf
kdump_conf=/etc/kdump.conf
kdump_conf_kdumphelper=/etc/kdump.conf.kdumphelper.$(date +%y-%m-%d-%H:%M:%S)
echo backup $kdump_conf to $kdump_conf_kdumphelper
cp $kdump_conf $kdump_conf_kdumphelper
dump_path=/var/crash
echo path $dump_path > $kdump_conf
dump_level=31
echo core_collector makedumpfile -c --message-level 1 -d $dump_level >> $kdump_conf
echo 'default reboot' >>  $kdump_conf

#enable kdump service
echo chkconfig kdump service on for 3 and 5 run levels
chkconfig kdump on --level 35
chkconfig --list|grep kdump

#kernel parameter change
echo Starting to Configure extra diagnostic opstions
sysctl_conf=/etc/sysctl.conf
sysctl_conf_kdumphelper=/etc/sysctl.conf.kdumphelper.$(date +%y-%m-%d-%H:%M:%S)
echo backup $sysctl_conf to $sysctl_conf_kdumphelper
cp $sysctl_conf $sysctl_conf_kdumphelper

#server hang
sed -i '/^kernel.sysrq/ s/kernel/#kernel/g ' $sysctl_conf 
echo >> $sysctl_conf
echo '#Panic on sysrq and nmi button, magic button alt+printscreen+c or nmi button could be pressed to collect a vmcore' >> $sysctl_conf
echo '#Added by kdumphelper, more information about it can be found in solution below' >> $sysctl_conf
echo '#https://access.redhat.com/site/solutions/2023' >> $sysctl_conf
echo 'kernel.sysrq=1' >> $sysctl_conf
echo 'kernel.sysrq=1 set in /etc/sysctl.conf'
echo '#https://access.redhat.com/site/solutions/125103' >> $sysctl_conf
echo 'kernel.unknown_nmi_panic=1' >> $sysctl_conf
echo 'kernel.unknown_nmi_panic=1  set in /etc/sysctl.conf'

#oom
sed -i '/^kernel.panic_on_oom/ s/kernel/#kernel/g ' $sysctl_conf 
echo >> $sysctl_conf
echo '#Panic on out of memory.' >> $sysctl_conf
echo '#Added by kdumphelper, more information about it can be found in solution below' >> $sysctl_conf
echo '#https://access.redhat.com/site/solutions/20985' >> $sysctl_conf
echo 'vm.panic_on_oom=1' >> $sysctl_conf
echo 'vm.panic_on_oom=1 set in /etc/sysctl.conf'

