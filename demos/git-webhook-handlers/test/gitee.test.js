const { gitee } = require('../lib')
const http = require('http')

const git = gitee({
  path: '/gitee',
  secret: 'secret',
})

http
  .createServer(async function (req, res) {
    const data = await git.handler(req)
    console.log('finish---', data)
    res.statusCode = 200
    res.end('text')
    // res.end(data.toString())
  })
  .listen(8080)
