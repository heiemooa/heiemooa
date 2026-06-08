#!/usr/bin/env bash

# debian 新机器默认配置

set -euo pipefail

USERNAME=${1:-zeyu}
USER_PASSWORD=${USER_PASSWORD:-}
NODE_MAJOR=${NODE_MAJOR:-22}

if [ "$(id -u)" -ne 0 ]; then
  echo "请使用 root 执行：sudo bash $0"
  exit 1
fi

source /etc/os-release
OS_ID="$ID"
CODENAME="$VERSION_CODENAME"

case "$OS_ID" in
  debian|ubuntu) ;;
  *)
    echo "当前系统 $PRETTY_NAME 暂不支持，仅支持 Debian/Ubuntu"
    exit 1
    ;;
esac

# 如果之前写入了错误的 Docker 源，先清理，避免 apt update 失败
rm -f /etc/apt/sources.list.d/docker.list

# 上海时间
timedatectl set-timezone Asia/Shanghai

apt update
apt upgrade -y
apt install -y ca-certificates curl gnupg vim wget zsh git sudo

# 安装 Node.js 和 Yarn。不要 apt install yarn，Ubuntu 会误装 cmdtest。
rm -f /etc/apt/sources.list.d/nodesource.list
curl --retry 5 --retry-delay 3 --connect-timeout 20 -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
  | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg

cat >/etc/apt/sources.list.d/nodesource.list <<EOF
deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main
EOF

apt update
apt install -y nodejs
corepack enable
corepack prepare yarn@stable --activate

# 创建默认用户
if ! id "$USERNAME" >/dev/null 2>&1; then
  useradd -m -s /usr/bin/zsh "$USERNAME"
else
  chsh -s /usr/bin/zsh "$USERNAME"
fi

if [ "$USERNAME" != "root" ]; then
  if [ -n "$USER_PASSWORD" ]; then
    echo "$USERNAME:$USER_PASSWORD" | chpasswd
  elif passwd -S "$USERNAME" | grep -q ' L '; then
    passwd "$USERNAME"
  fi
fi

if [ "$USERNAME" != "root" ]; then
  usermod -aG sudo "$USERNAME"

  cat >/etc/sudoers.d/99-"$USERNAME" <<EOF
$USERNAME ALL=(ALL:ALL) NOPASSWD:ALL
EOF

  chmod 0440 /etc/sudoers.d/99-"$USERNAME"
  visudo -cf /etc/sudoers.d/99-"$USERNAME"
fi

# 安装 Docker Engine 和 Compose V2 插件：命令为 docker compose，不是 docker-compose
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
  apt remove -y "$pkg" >/dev/null 2>&1 || true
done

install -m 0755 -d /etc/apt/keyrings
DOCKER_APT_BASE=${DOCKER_APT_BASE:-https://download.docker.com/linux/$OS_ID}

if ! curl --retry 5 --retry-delay 3 --connect-timeout 20 -fsSL "$DOCKER_APT_BASE/gpg" -o /etc/apt/keyrings/docker.asc; then
  for mirror in \
    "https://mirrors.cloud.tencent.com/docker-ce/linux/$OS_ID" \
    "https://mirrors.aliyun.com/docker-ce/linux/$OS_ID"; do
    if curl --retry 3 --retry-delay 3 --connect-timeout 20 -fsSL "$mirror/gpg" -o /etc/apt/keyrings/docker.asc; then
      DOCKER_APT_BASE="$mirror"
      break
    fi
  done
fi

if [ ! -s /etc/apt/keyrings/docker.asc ]; then
  echo "Docker GPG key 下载失败，请检查服务器网络或手动设置 DOCKER_APT_BASE"
  exit 1
fi

chmod a+r /etc/apt/keyrings/docker.asc

ARCH="$(dpkg --print-architecture)"

cat >/etc/apt/sources.list.d/docker.list <<EOF
deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.asc] $DOCKER_APT_BASE $CODENAME stable
EOF

apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker

[ "$USERNAME" = "root" ] || usermod -aG docker "$USERNAME"

# 修改 ssh 配置
# sed -i 's|UsePAM yes|UsePAM no|' /etc/ssh/sshd_config
sed -i 's|#\?\s*PasswordAuthentication no|PasswordAuthentication yes|' /etc/ssh/sshd_config
sed -i 's|#\?\s*PermitRootLogin [^ ]*|PermitRootLogin yes|' /etc/ssh/sshd_config
# 如何还是不能账号密码登录，检查 /etc/ssh/sshd_config.d/* 下的子文件，可能被这些文件覆盖了配置
# sed -i 's|PasswordAuthentication no|PasswordAuthentication yes|' /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
sed -i 's|X11Forwarding yes|X11Forwarding no|' /etc/ssh/sshd_config
sed -i 's|#ClientAliveInterval 0|ClientAliveInterval 60|' /etc/ssh/sshd_config
sed -i 's|#ClientAliveCountMax 3|ClientAliveCountMax 10|' /etc/ssh/sshd_config
if systemctl list-unit-files sshd.service >/dev/null 2>&1; then
  systemctl restart sshd
else
  systemctl restart ssh
fi


sudo -i -u "$USERNAME" bash <<EOF
set -e

# zsh
[ -e ~/.zshrc ] || curl --retry 3 --retry-delay 3 --connect-timeout 20 -sfo ~/.zshrc https://raw.githubusercontent.com/heiemooa/heiemooa/refs/heads/main/config/.zshrc || touch ~/.zshrc

# 安装 ohmyzsh 主题
echo \$SHELL
if [ ! -d ~/.oh-my-zsh ]; then
  git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git ~/.oh-my-zsh \
    || git clone --depth=1 https://gitee.com/mirrors/oh-my-zsh.git ~/.oh-my-zsh \
    || true
fi

if [ -d ~/.oh-my-zsh ]; then
  mkdir -p ~/.oh-my-zsh/custom/plugins
  [ -e ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions ] || git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions || true
  [ -e ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting ] || git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting || true

  sed -i '/^plugins=.*\(docker\|zsh-autosuggestions\|zsh-syntax-highlighting\)/! s/^plugins=(/&docker zsh-autosuggestions zsh-syntax-highlighting /' ~/.zshrc
  sed -i 's|^ZSH_THEME="robbyrussell"|ZSH_THEME="alanpeabody"|' ~/.zshrc
fi

# ssh
mkdir -p ~/.ssh
chmod 700 ~/.ssh
[ ! -e ~/.ssh/id_rsa ] || chmod 600 ~/.ssh/id_rsa
[ -e ~/.ssh/authorized_keys ] || (touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys)
EOF

docker --version
docker compose version

# 如果之前脚本写坏过 Docker 源，先清理一次再跑
# sudo rm -f /etc/apt/sources.list.d/docker.list

# 如果你已经是 root：
# curl -fsSL https://raw.githubusercontent.com/heiemooa/heiemooa/main/config/debian.sh | bash -s -- zeyu

# 如果你是普通 sudo 用户：
# curl -fsSL https://raw.githubusercontent.com/heiemooa/heiemooa/main/config/debian.sh | sudo bash -s -- zeyu

# 如果想一键创建 zeyu 并直接设置密码，可以这样：
# read -rsp 'zeyu password: ' PW; echo; curl -fsSL https://raw.githubusercontent.com/heiemooa/heiemooa/main/config/debian.sh | sudo USER_PASSWORD="$PW" bash -s -- zeyu
