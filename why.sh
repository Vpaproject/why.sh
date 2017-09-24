#!/bin/bash

yum -y update
yum -y install epel-release
yum -y install vim fail2ban httpd mariadb-server mariadb php php-mysql bind wget ssmtp nfs-common clamav-server clamav-data clamav-update clamav-filesystem clamav clamav-scanner-systemd clamav-devel clamav-lib clamav-server-systemd mlocate iftop nload sysstat ntp lsyncd yum-cron mod_ssl python-certbot-apache bind-utils jwhois php-xml php-gd git
mkdir -p /root/scripts/cronjobs/

# Enable and start Fail2Ban
systemctl enable fail2ban
systemctl start fail2ban

# Disable SELINUX for now
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config

# AWS Set hostname
hostnamectl set-hostname --static XXXX.devindice.com
echo "preserve_hostname: true" >> /etc/cloud/cloud.cfg

# Create SSH user
useradd $USER
echo $PASS | passwd $USER

# Delete root password
passwd -d root

# Generate root keys and set permissions
ssh-keygen -t rsa
chmod 755 /root/.ssh
chmod 644 /root/.ssh/authorized_keys
chmod 600 /root/.ssh/id_rsa
cat /root/.ssh/id_rsa.pub

# Uncomment and enable root logins
sed -i 's/#PermitRootLogin/PermitRootLogin/g' /etc/ssh/sshd_config
sed -i 's/PermitRootLogin no/PermitRootLogin yes/g' /etc/ssh/sshd_config
systemctl restart sshd

# Userkey
mkdir /home/$USER/.ssh
vim /home/$USER/.ssh/authorized_keys
rm /etc/sudoers.d/90-cloud-init-users
#-------------------------------------------------
echo "# User rules for centos" > /etc/sudoers.d/users
echo "$USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/users
#-------------------------------------------------

# Delete AWS user "centos"
userdel centos
rm -rf /home/centos

#Start LAMP services
systemctl start httpd.service
systemctl status httpd.service
systemctl enable httpd.service
systemctl start mariadb
systemctl status mariadb
systemctl enable mariadb.service

#Start BIND services
systemctl start named
systemctl status named
systemctl enable named.service

# Google Drive (used for backups): https://github.com/prasmussen/gdrive
wget https://docs.google.com/uc?id=0B3X9GlR6EmbnQ0FtZmJJUXEyRTA&export=download
mv uc\?id\=0B3X9GlR6EmbnQ0FtZmJJUXEyRTA gdrive
chmod +x gdrive
install gdrive /usr/bin/gdrive and/or install gdrive /usr/local/bin/gdrive 
gdrive about
gdrive list

# Configure and Secure MYSQL
mysql_secure_installation
#passwordless mysql client login for root
#vim /root/.my.cnf
echo '[client]' >> /root/.my.cnf
echo 'user=root' >> /root/.my.cnf
echo 'password=XYZ' >> /root/.my.cnf
chmod 400 /root/.my.cnf
chown root:root /root/.my.cnf

# SMTP Mail (ssmtp) for emailing alerts
ln -s /usr/sbin/ssmtp /usr/sbin/mail
mv /etc/ssmtp/ssmtp.conf /etc/ssmtp/ssmtp.conf.backup
#-------------------------------------------------
# /etc/ssmtp/ssmtp.conf
#-------------------------------------------------
echo 'TLS_CA_FILE=/etc/pki/tls/certs/ca-bundle.crt' > /etc/ssmtp/ssmtp.conf
echo 'root=email@gmail.com' >> /etc/ssmtp/ssmtp.conf
echo 'mailhub=smtp.gmail.com:587' >> /etc/ssmtp/ssmtp.conf
echo 'rewriteDomain=gmail.com' >> /etc/ssmtp/ssmtp.conf
echo 'hostname=east-web1' >> /etc/ssmtp/ssmtp.conf
echo 'UseTLS=YES' >> /etc/ssmtp/ssmtp.conf
echo 'UseSTARTTLS=YES' >> /etc/ssmtp/ssmtp.conf
echo 'AuthUser=email@gmail.com' >> /etc/ssmtp/ssmtp.conf
echo 'AuthPass=password' >> /etc/ssmtp/ssmtp.conf
echo 'AuthMethod=LOGIN' >> /etc/ssmtp/ssmtp.conf
echo 'FromLineOverride=YES' >> /etc/ssmtp/ssmtp.conf
#-------------------------------------------------

# Configure clam antivirus
cp /usr/share/clamav/template/clamd.conf /etc/clamd.d/clamd.conf
#remove example lines:
sed -i 's/Example/#Example/g' /etc/clamd.d/clamd.conf
sed -i 's/Example/#Example/g' /etc/clamd.d/scan.conf
sed -i 's/Example/#Example/g' /etc/freshclam.conf
#-------------------------------------------------
# /usr/lib/systemd/system/clam-freshclam.service
#-------------------------------------------------
echo '# Run the freshclam as daemon' >> /usr/lib/systemd/system/clam-freshclam.service
echo '[Unit]' >> /usr/lib/systemd/system/clam-freshclam.service
echo 'Description = freshclam scanner' >> /usr/lib/systemd/system/clam-freshclam.service
echo 'After = network.target' >> /usr/lib/systemd/system/clam-freshclam.service
echo '' >> /usr/lib/systemd/system/clam-freshclam.service
echo '[Service]' >> /usr/lib/systemd/system/clam-freshclam.service
echo 'Type = forking' >> /usr/lib/systemd/system/clam-freshclam.service
echo 'ExecStart = /usr/bin/freshclam -d -c 4' >> /usr/lib/systemd/system/clam-freshclam.service
echo 'Restart = on-failure' >> /usr/lib/systemd/system/clam-freshclam.service
echo 'PrivateTmp = true' >> /usr/lib/systemd/system/clam-freshclam.service
echo '' >> /usr/lib/systemd/system/clam-freshclam.service
echo '[Install]' >> /usr/lib/systemd/system/clam-freshclam.service
echo 'WantedBy=multi-user.target' >> /usr/lib/systemd/system/clam-freshclam.service
#-------------------------------------------------
systemctl enable clam-freshclam.service
systemctl start clam-freshclam.service
systemctl status clam-freshclam.service

mkdir /quarantine
chmod 700 /quarantine

[Download Custom Clam Scipt]

# Configure systat sar monitoring for every 2 minutes
sed -i 's/\*\/10/\*\/2/g' /etc/cron.d/sysstat
systemctl start sysstat.service
systemctl status sysstat.service
chkconfig sysstat on 

# Configure NTP
# /etc/ntp.conf
# NTP uses port UDP Port 123
systemctl start ntpd
chkconfig ntpd on
tzselect
rm /etc/localtime && ln -s /usr/share/zoneinfo/UTC /etc/localtime


# lsyncd
#-------------------------------------------------
# Dont Start or Enable LSYNCD until Configured
#-------------------------------------------------
#systemctl start lsyncd.service
#systemctl status lsyncd.service
#systemctl enable lsyncd.service


# Auto Updates (yum-cron)
cp /etc/yum/yum-cron.conf /etc/yum/yum-cron.conf.backup
cp /etc/yum/yum-cron-hourly.conf /etc/yum/yum-cron-hourly.conf.backup
# /etc/yum/yum-cron.conf
#-------------------------------------------------
# /etc/yum/yum-cron.conf
#-------------------------------------------------
echo '[commands]' > /etc/yum/yum-cron.conf
echo 'update_cmd = default' >> /etc/yum/yum-cron.conf
echo 'update_messages = yes' >> /etc/yum/yum-cron.conf
echo 'download_updates = yes' >> /etc/yum/yum-cron.conf
echo 'apply_updates = yes' >> /etc/yum/yum-cron.conf
echo 'random_sleep = 0' >> /etc/yum/yum-cron.conf
echo '[emitters]' >> /etc/yum/yum-cron.conf
echo 'system_name = None' >> /etc/yum/yum-cron.conf
echo 'emit_via = stdio' >> /etc/yum/yum-cron.conf
echo 'output_width = 80' >> /etc/yum/yum-cron.conf
echo '[email]' >> /etc/yum/yum-cron.conf
echo 'email_from = root' >> /etc/yum/yum-cron.conf
echo 'email_to = root' >> /etc/yum/yum-cron.conf
echo 'email_host = localhost' >> /etc/yum/yum-cron.conf
echo '[groups]' >> /etc/yum/yum-cron.conf
echo 'group_list = None' >> /etc/yum/yum-cron.conf
echo 'group_package_types = mandatory, default' >> /etc/yum/yum-cron.conf
echo '[base]' >> /etc/yum/yum-cron.conf
echo 'debuglevel = -2' >> /etc/yum/yum-cron.conf
echo 'mdpolicy = group:main' >> /etc/yum/yum-cron.conf
#-------------------------------------------------
# /etc/yum/yum-cron-hourly.conf
#-------------------------------------------------
echo '[commands]' > /etc/yum/yum-cron-hourly.conf
echo 'update_cmd = security-severity:Critical' >> /etc/yum/yum-cron-hourly.conf
echo 'update_messages = yes' >> /etc/yum/yum-cron-hourly.conf
echo 'download_updates = yes' >> /etc/yum/yum-cron-hourly.conf
echo 'apply_updates = yes' >> /etc/yum/yum-cron-hourly.conf
echo 'random_sleep = 0' >> /etc/yum/yum-cron-hourly.conf
echo '[emitters]' >> /etc/yum/yum-cron-hourly.conf
echo 'system_name = None' >> /etc/yum/yum-cron-hourly.conf
echo 'emit_via = stdio' >> /etc/yum/yum-cron-hourly.conf
echo 'output_width = 80' >> /etc/yum/yum-cron-hourly.conf
echo '[email]' >> /etc/yum/yum-cron-hourly.conf
echo 'email_from = root' >> /etc/yum/yum-cron-hourly.conf
echo 'email_to = root' >> /etc/yum/yum-cron-hourly.conf
echo 'email_host = localhost' >> /etc/yum/yum-cron-hourly.conf
echo '[groups]' >> /etc/yum/yum-cron-hourly.conf
echo 'group_list = None' >> /etc/yum/yum-cron-hourly.conf
echo 'group_package_types = mandatory, default' >> /etc/yum/yum-cron-hourly.conf
echo '[base]' >> /etc/yum/yum-cron-hourly.conf
echo 'debuglevel = -2' >> /etc/yum/yum-cron-hourly.conf
echo 'mdpolicy = group:main' >> /etc/yum/yum-cron-hourly.conf
#-------------------------------------------------
mv /etc/cron.daily/0yum-daily.cron /root/scripts/cronjobs/
mv /etc/cron.hourly/0yum-hourly.cron /root/scripts/cronjobs/
systemctl start yum-cron.service
systemctl status yum-cron.service
systemctl enable yum-cron.service

# Configure Crontab
#-------------------------------------------------
# /etc/crontab
#-------------------------------------------------
echo 'SHELL=/bin/bash' > /etc/crontab
echo 'PATH=/sbin:/bin:/usr/sbin:/usr/bin' >> /etc/crontab
echo 'MAILTO=root' >> /etc/crontab
echo '' >> /etc/crontab
echo '# For details see man 4 crontabs' >> /etc/crontab
echo '' >> /etc/crontab
echo '# Job definition:' >> /etc/crontab
echo '#  .-------------------- minute (0 - 59)' >> /etc/crontab
echo '#  |   .---------------- hour (0 - 23)' >> /etc/crontab
echo '#  |   |  .------------- day of month (1 - 31)' >> /etc/crontab
echo '#  |   |  |     .------- month (1 - 12) OR jan,feb,mar,apr ...' >> /etc/crontab
echo '#  |   |  |     |  .---- day of week (0 - 6) (Sunday=0 or 7) OR sun,mon,tue,wed,thu,fri,sat' >> /etc/crontab
echo '#  |   |  |     |  |' >> /etc/crontab
echo '#  *   *  *     *  *     user-name  command to be executed' >> /etc/crontab
echo '' >> /etc/crontab
echo '### DEFAULT ###' >> /etc/crontab
echo '   1 3 * * 1-6 root /root/scripts/cronjobs/clamav_scan_daily.sh >> /dev/null 2>&1' >> /etc/crontab
echo '   1 3 * * 7 root /root/scripts/cronjobs/clamav_scan_weekly.sh >> /dev/null 2>&1' >> /etc/crontab
echo '' >> /etc/crontab
echo '### Server ###' >> /etc/crontab
echo '' >> /etc/crontab
echo '### devindice.com ###' >> /etc/crontab
#-------------------------------------------------
