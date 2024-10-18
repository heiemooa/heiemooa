基于 nodejs 实现对 git webhook 处理的，支持:

- github
- gitee
- gitlab
- codeup

## 使用

```
const { gitee } = require("git-webhook-handlers");
const http = require('http');

const handler = gitee({
  path: "/gitee",
  secret: 'secret'
});

http.createServer(function async (req, res) {
  const data = await handler(req);
  res.statusCode = 200;
  res.end(JSON.string(data));
}).listen(8080)

```
