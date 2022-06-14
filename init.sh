
echo "Let's start initial basic setup"
apt update
apt upgrade
apt autoremove
apt clean

timedatectl set-timezone Asia/Tokyo
locale-gen "en_US.UTF-8"
dpkg-reconfigure locales

echo "Enter first user name(this user will be automatically granted administrative privilege)"
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

git config --global init.defaultBranch main
echo
echo "Enter git user.name"
read $gitUserName

git config --global user.name $gitUserName
echo
echo "Enter git user.email"
read $gitUserEmail

git config --global user.email $gitUserEmail

apt install neovim

mkdir ~/.config
mkdir ~/.config/nvim
mv init.vim ~/.config/nvim/init.vim

apt install curl
curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

mkdir ~/.vim
mkdir ~/.vim/plugged

echo
echo "Please run :PlugInstall in neovim to install plugins"
echo 