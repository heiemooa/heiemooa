#!/usr/bin/env bash

# ubuntu 新机器默认配置

# 上海时间
sudo timedatectl set-timezone Asia/Shanghai

set -e

apt update && apt upgrade -y
apt install -y vim curl wget zsh git yarn docker.io docker-compose

# 先创建用户
# sudo useradd -m emooa
# sudo passwd emooa

USERNAME=${1:-emooa}
chsh -s /usr/bin/zsh "$USERNAME"

[ "$USERNAME" = "root" ] || usermod -aG docker "$USERNAME"

[ "$USERNAME" = "root" ] || usermod -aG sudo "$USERNAME"

# 修改 ssh 配置
# sed -i 's|UsePAM yes|UsePAM no|' /etc/ssh/sshd_config
sed -i 's|#\?\s*PasswordAuthentication no|PasswordAuthentication yes|' /etc/ssh/sshd_config
sed -i 's|#\?\s*PermitRootLogin [^ ]*|PermitRootLogin yes|' /etc/ssh/sshd_config
# 如何还是不能账号密码登录，检查 /etc/ssh/sshd_config.d/* 下的子文件，可能被这些文件覆盖了配置
# sed -i 's|PasswordAuthentication no|PasswordAuthentication yes|' /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
sed -i 's|X11Forwarding yes|X11Forwarding no|' /etc/ssh/sshd_config
sed -i 's|#ClientAliveInterval 0|ClientAliveInterval 60|' /etc/ssh/sshd_config
sed -i 's|#ClientAliveCountMax 3|ClientAliveCountMax 10|' /etc/ssh/sshd_config
systemctl restart sshd 
# 如果 ssh 重启失败，检查 SSH 服务名称：systemctl list-units --type=service | grep ssh
# systemctl restart ssh.service


sudo -i -u "$USERNAME" bash <<EOF
set -e

# 安装 ohmyzsh 主题
echo $SHELL
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" --unattended

[ -e .oh-my-zsh/custom/plugins/zsh-autosuggestions ] || git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions .oh-my-zsh/custom/plugins/zsh-autosuggestions

sed -i '/^plugins=/ s/)/ docker zsh-autosuggestions)/' ~/.zshrc
sed -i 's|^ZSH_THEME="robbyrussell"|ZSH_THEME="dpoggi"|' ~/.zshrc
source .zshrc

EOF