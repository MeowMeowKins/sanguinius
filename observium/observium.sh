#!/bin/bash
##
##	20/04/2017
##
##	CentOS 7
##	Kernel: 4.13.16-2
##	Observium

setenforce 0

yum update -y
yum upgrade -y

yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm -y
yum install https://mirror.webtatic.com/yum/el7/webtatic-release.rpm -y
yum install http://yum.opennms.org/repofiles/opennms-repo-stable-rhel7.noarch.rpm -y
yum install wget.x86_64 httpd.x86_64 php56w.x86_64 php56w-opcache.x86_64 php56w-mysql.x86_64 php56w-gd.x86_64 php56w-posix php56w-mcrypt.x86_64 php56w-pear.noarch cronie.x86_64 net-snmp.x86_64 net-snmp-utils.x86_64 fping.x86_64 mariadb-server.x86_64 mariadb.x86_64 MySQL-python.x86_64 rrdtool.x86_64 subversion.x86_64 jwhois.x86_64 ipmitool.x86_64 graphviz.x86_64 ImageMagick.x86_64 -y

mkdir -p /opt/observium

wget http://www.observium.org/observium-community-latest.tar.gz -P /opt/
tar zxvf /opt/observium-community-latest.tar.gz -C /opt/

systemctl enable mariadb
systemctl start mariadb

read -sp 'Password for MySQL root: ' mysqlrootpass
echo
echo
read -sp 'Password for observium database user: ' observiumdbpass

/usr/bin/mysqladmin -u root password $mysqlrootpass


mysql -uroot -p${mysqlrootpass} -e "CREATE DATABASE observium CHARACTER SET utf8 COLLATE utf8_general_ci;"
mysql -uroot -p${mysqlrootpass} -e "GRANT ALL PRIVILEGES ON observium.* to 'observium'@'localhost' IDENTIFIED BY '$observiumdbpass';"
cp /opt/observium/config.php.default /opt/observium/config.php
sed -i.bak -e '11d;12d' /opt/observium/config.php
# db_user
sed -e "11idollarsignconfig['db_user'] \t= 'observium';" -i /opt/observium/config.php
sed -e 's/\(dollarsign\)/\1\$/' -i /opt/observium/config.php
sed -e 's/\<dollarsign\>//g' -i /opt/observium/config.php
# db_password
sed -e "12idollarsignconfig['db_pass'] \t= '$mysqlrootpass';" -i /opt/observium/config.php
sed -e 's/\(dollarsign\)/\1\$/' -i /opt/observium/config.php
sed -e 's/\<dollarsign\>//g' -i /opt/observium/config.php
/opt/observium/discovery.php -u

# fping config
sed -e "18idollarsignconfig['fping'] = \"/sbin/fping\";" -i /opt/observium/config.php
sed -e 's/\(dollarsign\)/\1\$/' -i /opt/observium/config.php
sed -e 's/\<dollarsign\>//g' -i /opt/observium/config.php


mkdir /opt/observium/rrd
chown -R apache:apache /opt/observium/rrd
mkdir /opt/observium/logs
chown -R apache:apache /opt/observium/logs

echo
echo
read -p 'Domain name:' servernameapache
echo
echo

rm /etc/httpd/conf.d/observium.conf
HTTPDFILE="/etc/httpd/conf.d/observium.conf"
echo "<VirtualHost *>" >> $HTTPDFILE
echo -e "\tDocumentRoot /opt/observium/html/" >> $HTTPDFILE
echo -e "\tServerName ${servernameapache}" >> $HTTPDFILE
echo -e "\tCustomLog /opt/observium/logs/access_log combined" >> $HTTPDFILE
echo -e "\tErrorLog /opt/observium/logs/error_log" >> $HTTPDFILE
echo -e "\t<Directory \"/opt/observium/html/\">" >> $HTTPDFILE
echo -e "\t\tAllowOverride All" >> $HTTPDFILE
echo -e "\t\tOptions FollowSymLinks MultiViews" >> $HTTPDFILE
echo -e "\t\tRequire all granted" >> $HTTPDFILE
echo -e "\t</Directory>" >> $HTTPDFILE
echo '</VirtualHost>' >> $HTTPDFILE

sed -i.bak -e '7d' /etc/selinux/config
sed -e "7iSELINUX=disabled" -i /etc/selinux/config

firewall-cmd --permanent --zone=public --add-service=http
firewall-cmd --reload

systemctl enable httpd
systemctl start httpd

CRON="/etc/cron.d/observium"
touch $CRON
# Run a complete discovery of all devices once every 6 hours
echo -e "33  */6\t* * *\troot\t/opt/observium/discovery.php -h all >> /dev/null 2>&1" >> $CRON
# Run automated discovery of newly added devices every 5 minutes
echo -e "*/5 *\t* * *\troot\t/opt/observium/discovery.php -h new >> /dev/null 2>&1" >> $CRON
# Run multithreaded poller wrapper every 5 minutes
echo -e "*/5 *\t* * *\troot\t/opt/observium/poller-wrapper.py 8 >> /dev/null 2>&1" >> $CRON
# Run housekeeping script daily for syslog, eventlog and alert log
echo -e "13 5 * * * root /opt/observium/housekeeping.php -ysel" >> $CRON
# Run housekeeping script daily for rrds, ports, orphaned entries in the database and performance data
echo -e "47 4 * * * root /opt/observium/housekeeping.php -yrptb" >> $CRON
systemctl reload crond

echo "We're done!"
