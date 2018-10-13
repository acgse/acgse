#!/bin/bash
# Description: script to init configuration to new server.
#--------------------------------------------------------------|
#   @Program    : System_init.sh                               |  
#   @Version    : 1.1                                          |
#   @Company    : QWKG                                         |
#   @Dep.       : IDC                                          |
#   @Writer     : wangshibo   <wangshibo@veredholdings.com>    |                
#   @Date       : 2017-11-07                                   |
#   @Modify     : wangshibo                                    |
#--------------------------------------------------------------|

#临时dns设置，用于yum下载
echo "nameserver 8.8.8.8" /etc/resolv.conf
echo "nameserver 8.8.4.4" /etc/resolv.conf

#设置ntp时间服务
/usr/bin/yum install -y ntpdate
/usr/sbin/ntpdate 10.0.11.26
echo "*/5 * * * * /usr/sbin/ntpdate 10.0.11.26 > /dev/null 2>&1" >>/var/spool/cron/root
echo "*/5 * * * * /usr/sbin/ntpdate 10.0.11.27 > /dev/null 2>&1" >>/var/spool/cron/root
echo "*/5 * * * * /usr/sbin/ntpdate 10.0.11.28 > /dev/null 2>&1" >>/var/spool/cron/root
chmod 600 /var/spool/cron/root

#关闭防火墙
iptables -F
iptables -X
systemctl stop firewalld.service
systemctl disable firewalld.service 
sed -i 's/SELINUX=enforcing/SELINUX=disabled/'  /etc/selinux/config 

#设置DNS
\cp -f /etc/resolv.conf /etc/resolv.conf.bak
> /etc/resolv.conf
echo "domain veredholdings.cn" >> /etc/resolv.conf
echo "search veredholdings.cn" >> /etc/resolv.conf
echo "nameserver 10.0.11.21" >> /etc/resolv.conf
echo "nameserver 10.0.11.22" >> /etc/resolv.conf
/usr/bin/chattr +ai /etc/resolv.conf

#更换为内网yum源
cd /etc/yum.repos.d/
/bin/mkdir /etc/yum.repos.d/bak
mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/bak
wget http://10.0.8.50/software/CentOS-Base.repo
wget http://10.0.8.50/software/epel.repo
/usr/bin/yum clean all
/usr/bin/yum makecache

#内核参数优化
/bin/cat << EOF > /etc/sysctl.conf
kernel.sysrq = 1
kernel.core_uses_pid = 1
fs.aio-max-nr = 1048576                
kernel.msgmnb = 65536
kernel.msgmax = 65536
kernel.shmmax = 68719476736
kernel.shmall = 4294967296
net.ipv4.ip_forward = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.default.rp_filter = 2
net.ipv4.conf.all.rp_filter = 2
net.ipv4.conf.all.arp_announce = 2
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_tw_recycle = 1
net.ipv4.ip_local_port_range = 1024  65535
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_synack_retries = 2
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.rp_filter = 1
net.core.somaxconn = 65535
net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 8192 87380 16777216
net.ipv4.tcp_wmem = 8192 65536 16777216
net.ipv4.tcp_max_syn_backlog = 16384
net.core.netdev_max_backlog = 10000
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_orphan_retries = 0
net.ipv4.tcp_max_orphans = 131072
#fs.file-max = 65536  #os can config
vm.min_free_kbytes = 1048576
vm.swappiness = 10
vm.dirty_ratio = 10
vm.vfs_cache_pressure=150
vm.drop_caches = 1
kernel.panic = 60
EOF
/sbin/sysctl -p >/dev/null 2>&1;


#ssh登陆优化
cp /etc/ssh/sshd_config{,.bak}  
#sed -e 's/\#PermitRootLogin yes/PermitRootLogin no/' -i /etc/ssh/sshd_config > /dev/null 2>&1
sed -e 's/GSSAPIAuthentication yes/GSSAPIAuthentication no/' -i /etc/ssh/sshd_config > /dev/null 2>&1
sed -e 's/#UseDNS yes/UseDNS no/' -i /etc/ssh/sshd_config > /dev/null 2>&1
systemctl restart sshd.service

#修改文件描述符数量
sed -i 's#4096#65535#g' /etc/security/limits.d/20-nproc.conf
/bin/cp /etc/security/limits.conf /etc/security/limits.conf.bak
echo '* soft nofile 65535'>>/etc/security/limits.conf
echo '* hard nofile 65535'>>/etc/security/limits.conf
echo '* soft nproc 102400'>>/etc/security/limits.conf
echo '* hard nproc 102400'>>/etc/security/limits.conf

# 安装常用软件
/usr/bin/yum groupinstall "Development Tools"
/usr/bin/yum install -y gcc  glibc  gcc-c++ make  lrzsz  tree  wget curl lsof dstat vim wsmancli ipmitool mtr sysstat ethtool systemtap strace 

/bin/rm /root/idc_system_centos7_init.sh
# 最后重启服务器
reboot
