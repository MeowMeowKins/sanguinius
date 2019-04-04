#!/bin/bash
##
##	20/04/2017
##
##	CentOS 7
##	Kernel: 4.13.16-2
##	Zabbix: 3.4

iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

yum update -y
yum upgrade -y
yum install httpd mariadb-server mariadb php php-mysql -y
systemctl start httpd
systemctl start mariadb
systemctl enable httpd
systemctl enable mariadb
systemctl restart httpd

read -sp 'Password for MySQL root: ' rootpass
echo 
read -sp 'Password for Zabbix database user: ' zbxpass
echo
read -sp 'Provide your timezone as you do in PHP: ' phptime
echo

mysql_secure_installation <<EOF

y
$rootpass
$rootpass
y
y
y
y
EOF

rpm -i http://repo.zabbix.com/zabbix/3.4/rhel/7/x86_64/zabbix-release-3.4-2.el7.noarch.rpm
yum install zabbix-server-mysql zabbix-web-mysql zabbix-agent -y
mysql -uroot -p$rootpass -Bse "create database zabbix character set utf8 collate utf8_bin;"
mysql -uroot -p$rootpass -Bse "grant all privileges on zabbix.* to zabbix@localhost identified by '$zbxpass';"
zcat /usr/share/doc/zabbix-server-mysql*/create.sql.gz | mysql -uzabbix -p zabbix --password=$zbxpass
sed -e "126iDBPassword=${rootpass}" -i /etc/zabbix/zabbix_server.conf
systemctl start zabbix-server
systemctl start zabbix-agent
systemctl restart httpd
systemctl enable zabbix-server
systemctl enable zabbix-agent
sed -e "19i		php_value date.timezone $phptime" -i /etc/httpd/conf.d/zabbix.conf
systemctl restart httpd
