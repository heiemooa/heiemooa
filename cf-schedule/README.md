# 定时器

功能：

- 基于 CLI 部署 cloudflare work，定时触发器
- 通过企业微信机器人定时推送天气预报

# 环境安装

## 安装 wrangler

```
npm install -g @cloudflare/wrangler
```

## 安装 登录

```
wrangler pages login
```

## 安装依赖

```
cd /cf-schedule
yarn # 安装依赖
```

## 修改环境变量

wrangler.toml

```
WECHAT_BOT_KEY = 'YOUR_WECHAT_BOT_KEY' # 企微机器人 WEBHOOK KEY
SENIVERSE_KEY = 'YOUR_SENIVERSE_KEY' # 心知天气KEY
WEATHER_CITY = 'YOUR_WEATHER_CITY' # 城市
```

# 本地运行

```
yarn dev
```

# 部署

```
yarn run deploy
```

## 修改 start.sh

运行 `pwd` 查看当前目录，比如 `/Users/emooa/heiemooa/wechat-hook` 修改为:

```
source /Users/emooa/heiemooa/wechat-hook/.frida/bin/activate
SEND_WECOM=1 python3 /Users/emooa/heiemooa/wechat-hook/main.py
```
