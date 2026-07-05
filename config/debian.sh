#!/usr/bin/env bash

# Debian/Ubuntu 新机器默认配置

set -Eeuo pipefail

log() {
  printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

trap 'echo "脚本失败：第 ${LINENO} 行：${BASH_COMMAND}" >&2' ERR

USERNAME=${1:-zeyu}
USER_PASSWORD=${USER_PASSWORD:-}
NODE_MAJOR=${NODE_MAJOR:-22}
ENABLE_PASSWORD_AUTH=${ENABLE_PASSWORD_AUTH:-1}
ENABLE_ROOT_LOGIN=${ENABLE_ROOT_LOGIN:-0}
export DEBIAN_FRONTEND=${DEBIAN_FRONTEND:-noninteractive}

if [ "$(id -u)" -ne 0 ]; then
  echo "请使用 root 执行：sudo bash $0"
  exit 1
fi

if [[ ! "$USERNAME" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]]; then
  echo "用户名不合法：$USERNAME"
  exit 1
fi

source /etc/os-release
OS_ID="$ID"
CODENAME="${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}"

case "$OS_ID" in
  debian|ubuntu) ;;
  *)
    echo "当前系统 $PRETTY_NAME 暂不支持，仅支持 Debian/Ubuntu"
    exit 1
    ;;
esac

if [ -z "$CODENAME" ]; then
  echo "无法从 /etc/os-release 识别系统代号，请手动设置 VERSION_CODENAME 后重试"
  exit 1
fi

# 如果之前写入了错误的 Docker 源，先清理，避免 apt update 失败
rm -f /etc/apt/sources.list.d/docker.list

# 上海时间
log "设置时区为 Asia/Shanghai"
timedatectl set-timezone Asia/Shanghai

log "更新系统并安装基础工具"
apt update
apt upgrade -y
apt install -y ca-certificates curl gnupg vim wget zsh git sudo openssh-server
install -m 0755 -d /etc/apt/keyrings

# 安装 Node.js 和 Yarn。不要 apt install yarn，Ubuntu 会误装 cmdtest。
log "安装 Node.js ${NODE_MAJOR}.x 和 Yarn"
rm -f /etc/apt/sources.list.d/nodesource.list
rm -f /etc/apt/keyrings/nodesource.gpg
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
log "创建或更新用户：$USERNAME"
USER_CREATED=0
if ! id "$USERNAME" >/dev/null 2>&1; then
  useradd -m -s /usr/bin/zsh "$USERNAME"
  USER_CREATED=1
else
  chsh -s /usr/bin/zsh "$USERNAME"
fi

if [ "$USERNAME" != "root" ]; then
  if [ -n "$USER_PASSWORD" ]; then
    echo "$USERNAME:$USER_PASSWORD" | chpasswd
  elif [ -r /dev/tty ]; then
    PASSWORD_STATUS="$(passwd -S "$USERNAME" 2>/dev/null | awk '{print $2}')"
    if [ "$USER_CREATED" = "1" ] || [ "$PASSWORD_STATUS" != "P" ]; then
      log "设置 $USERNAME 的登录密码"
      passwd "$USERNAME" </dev/tty
    fi
  else
    log "当前没有可交互终端，跳过密码设置；请稍后执行：sudo passwd $USERNAME"
  fi
fi

if [ "$USERNAME" != "root" ]; then
  log "授予 $USERNAME sudo 权限"
  usermod -aG sudo "$USERNAME"

  cat >/etc/sudoers.d/99-"$USERNAME" <<EOF
$USERNAME ALL=(ALL:ALL) NOPASSWD:ALL
EOF

  chmod 0440 /etc/sudoers.d/99-"$USERNAME"
  visudo -cf /etc/sudoers.d/99-"$USERNAME"
fi

# 安装 Docker Engine 和 Compose V2 插件：命令为 docker compose，不是 docker-compose
log "安装 Docker Engine 和 Docker Compose V2 插件"
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
  apt remove -y "$pkg" >/dev/null 2>&1 || true
done

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

if [ "$USERNAME" != "root" ]; then
  getent group docker >/dev/null || groupadd docker
  usermod -aG docker "$USERNAME"
fi

# 修改 ssh 配置
log "更新 SSH 配置"
install -m 0755 -d /etc/ssh/sshd_config.d
SSH_INIT_CONF=/etc/ssh/sshd_config.d/00-heiemooa-init.conf

if ! grep -Eq '^[[:space:]]*Include[[:space:]]+/etc/ssh/sshd_config\.d/\*\.conf' /etc/ssh/sshd_config; then
  sed -i '1i Include /etc/ssh/sshd_config.d/*.conf' /etc/ssh/sshd_config
fi

{
  echo "X11Forwarding no"
  echo "ClientAliveInterval 60"
  echo "ClientAliveCountMax 10"
  if [ "$ENABLE_PASSWORD_AUTH" = "1" ]; then
    echo "PasswordAuthentication yes"
  fi
  if [ "$ENABLE_ROOT_LOGIN" = "1" ]; then
    echo "PermitRootLogin yes"
  else
    echo "PermitRootLogin prohibit-password"
  fi
} >"$SSH_INIT_CONF"

sshd -t
if systemctl list-unit-files sshd.service >/dev/null 2>&1; then
  systemctl restart sshd
else
  systemctl restart ssh
fi

log "配置 $USERNAME 的 zsh、oh-my-zsh 和插件"
sudo -H -u "$USERNAME" bash <<'EOF'
set -euo pipefail

clone_if_missing() {
  local target=$1
  local primary=$2
  local mirror=${3:-}

  if [ -d "$target" ]; then
    return
  fi

  git clone --depth=1 "$primary" "$target" && return

  if [ -n "$mirror" ]; then
    git clone --depth=1 "$mirror" "$target" && return
  fi

  return 1
}

# zsh
if [ ! -f "$HOME/.zshrc" ]; then
  cat >"$HOME/.zshrc" <<'ZSHRC'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="alanpeabody"
plugins=(git docker zsh-autosuggestions zsh-syntax-highlighting)

if [ -f "$ZSH/oh-my-zsh.sh" ]; then
  source "$ZSH/oh-my-zsh.sh"
fi
ZSHRC
fi

# 安装 ohmyzsh 主题
if [ ! -d ~/.oh-my-zsh ]; then
  clone_if_missing "$HOME/.oh-my-zsh" \
    https://github.com/ohmyzsh/ohmyzsh.git \
    https://gitee.com/mirrors/oh-my-zsh.git || true
fi

if [ -d ~/.oh-my-zsh ]; then
  mkdir -p ~/.oh-my-zsh/custom/plugins
  clone_if_missing "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" \
    https://github.com/zsh-users/zsh-autosuggestions \
    "" || true
  clone_if_missing "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" \
    https://github.com/zsh-users/zsh-syntax-highlighting \
    "" || true

  if grep -q '^ZSH_THEME=' "$HOME/.zshrc"; then
    sed -i 's|^ZSH_THEME=.*|ZSH_THEME="alanpeabody"|' "$HOME/.zshrc"
  else
    sed -i '1i ZSH_THEME="alanpeabody"' "$HOME/.zshrc"
  fi

  if grep -q '^plugins=' "$HOME/.zshrc"; then
    sed -i 's|^plugins=.*|plugins=(git docker zsh-autosuggestions zsh-syntax-highlighting)|' "$HOME/.zshrc"
  else
    sed -i '/oh-my-zsh.sh/i plugins=(git docker zsh-autosuggestions zsh-syntax-highlighting)' "$HOME/.zshrc"
  fi
fi

# ssh
mkdir -p ~/.ssh
chmod 700 ~/.ssh
[ ! -e ~/.ssh/id_rsa ] || chmod 600 ~/.ssh/id_rsa
[ -e ~/.ssh/authorized_keys ] || (touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys)
EOF

log "验证安装结果"
docker --version
docker compose version
id "$USERNAME"

# 如果之前脚本写坏过 Docker 源，先清理一次再跑
# sudo rm -f /etc/apt/sources.list.d/docker.list

# 如果你已经是 root：
# curl -fsSL https://raw.githubusercontent.com/heiemooa/heiemooa/main/config/debian.sh | bash -s -- zeyu

# 如果你是普通 sudo 用户：
# curl -fsSL https://raw.githubusercontent.com/heiemooa/heiemooa/main/config/debian.sh | sudo bash -s -- zeyu

# 如果想一键创建 zeyu 并直接设置密码，可以这样：
# read -rsp 'zeyu password: ' PW; echo; curl -fsSL https://raw.githubusercontent.com/heiemooa/heiemooa/main/config/debian.sh | sudo USER_PASSWORD="$PW" bash -s -- zeyu
