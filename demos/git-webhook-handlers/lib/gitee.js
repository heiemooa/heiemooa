// gitee 签名方式：https://gitee.com/help/articles/4290#article-header1
const crypto = require('crypto')
const bl = require('bl')

function hasError(msg) {
  var err = new Error(msg)
  throw err
}

function sign(secret, stringToSign) {
  return crypto
    .createHmac('sha256', secret)
    .update(stringToSign)
    .digest('bytes')
    .toString('base64')
}

function verify(token, sign) {
  if (!token) {
    return hasError('No X-Gitee-Token found on request')
  }
  return token === sign
}

class Gitee {
  constructor(options) {
    this.options = options
  }

  async handler(req) {
    if (typeof this.options !== 'object') {
      throw new TypeError('must provide an options object')
    }

    if (typeof this.options.path !== 'string') {
      throw new TypeError("must provide a 'path' option")
    }

    if (this.options.secret && typeof this.options.secret !== 'string') {
      throw new TypeError("must provide a 'secret' option")
    }

    if (this.options.password && typeof this.options.password !== 'string') {
      throw new TypeError("must provide a 'password' option")
    }
    const { path = req.url.split('?').shift() } = req
    if (path !== this.options.path || req.method !== 'POST') {
      throw new Error(`${req.method} ${path} api is not supoort`)
    }

    let events

    if (
      typeof this.options.events === 'string' &&
      this.options.events !== '*'
    ) {
      events = [this.options.events]
    } else if (
      Array.isArray(this.options.events) &&
      this.options.events.indexOf('*') === -1
    ) {
      events = this.options.events
    }

    var event = req.headers['x-git-oschina-event']

    if (!event) {
      return hasError('No X-Git-Oschina-Event found on request')
    }

    if (events && events.indexOf(event) === -1) {
      return hasError('X-Gitee-Event is not acceptable')
    }

    req.pipe(
      bl((err, data) => {
        if (err) {
          return hasError(err.message)
        }

        let payload

        try {
          payload = JSON.parse(data.toString())
        } catch (e) {
          return hasError(e)
        }

        if (this.options.password) {
          if (!verify(req.headers['x-gitee-token'], this.options.password)) {
            return hasError('Password does not match')
          }
        }

        if (this.options.secret) {
          const stringToSign =
            req.headers['x-gitee-timestamp'] + '\n' + this.options.secret

          if (
            !verify(
              req.headers['x-gitee-token'],
              sign(this.options.secret, stringToSign)
            )
          ) {
            return hasError('Secret does not match')
          }
        }
        return {
          event,
          payload,
          protocol: req.protocol,
          host: req.headers['host'],
          url: req.url,
          path: req.path,
        }
      })
    )
  }
}

module.exports = (options) => new Gitee(options)
