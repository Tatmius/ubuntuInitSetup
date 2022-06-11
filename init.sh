echo "Let's start initial basic setup"
sudo apt update
sudo apt upgrade
sudo apt autoremove
sudo apt clean

timedatectl set-timezone Asia/Tokyo

echo "Enter first user name"
echo "Notice: this user will be automatically granted administrative privilege"
read firstUserName
adduser $firstUserName
usermod -aG sudo $firstUserName

ufw allow OpenSSH
ufw enable
ufw status

echo "change ssh port from 22 to 1600"
sed -e "s/#Port22/Port 1600/" /etc/ssh/sshd_config > /etc/ssh/tmp
mv /etc/ssh/tmp /etc/ssh/sshd_config

echo "change ssh PermitRootLogin yes to no"
sed -e "s/ #PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config > /etc/ssh/tmp
mv /etc/ssh/tmp /etc/ssh/sshd_config
systemctl restart sshd
ss -tlpn| grep ssh