# 逆向企业微信，通过群机器人监测公司人员变动

- 本地启动企业微信
- 创建群机器人，在 webhook 中拿到 key 写入 wechat-hook/.env 中，注意只需要拿到 KEY 就行
- 以下环境验证没问题
  - MacOS 14
  - 企业微信版本 4.1.33.70494

# 环境安装

## 安装 python3 和 pip3

```
python3 --version
python3 -m ensurepip --upgrade
pip3 --version
```

## 安装 frida-tools

```
pip install frida-tools
frida --version
```

# 运行脚本

## 进入 wechat-hook 目录

```
cd /wechat-hook
```

## 创建虚拟环境

```
python3 -m venv .frida
source .frida/bin/activate
```

## 安装依赖

```
pip3 install -r requirements.txt
```

## 修改 start.sh

运行 `pwd` 查看当前目录，比如 `/Users/emooa/heiemooa/wechat-hook` 修改为:

```
source /Users/emooa/heiemooa/wechat-hook/.frida/bin/activate
SEND_WECOM=1 python3 /Users/emooa/heiemooa/wechat-hook/main.py
```

## 修改 .env

替换为企业微信 webhook 的 KEY

```
WECHAT_BOT_KEY='KEY'
```

## 运行 start.sh，数据存储在 `.files` 目录下

```
sh start.sh
```
