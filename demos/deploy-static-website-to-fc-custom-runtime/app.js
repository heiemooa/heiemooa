let express = require('express')
let app = new express()
app.use(express.static('dist')) // 使用 dist 文件夹中的内容对外提供静态文件访问
app.use((req, res) => {
  res.redirect('/')
}) // 重定向无法处理的请求到网站的根目录
let port = 9000
app.listen(port, () => {
  console.log(`App started on port ${port}`)
}) // 监听 FC custom 运行时默认的 9000 端口
