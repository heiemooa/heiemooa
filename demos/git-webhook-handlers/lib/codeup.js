// Codeup 的 secret 是明文的。。。。
function hasError(msg) {
  var err = new Error(msg)
  throw err
}

function verify(token, sign) {
  if (!token) {
    return hasError('No X-Codeup-Token found on request')
  }
  return token === sign
}

class Codeup {
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

    const { path = req.url } = req
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

    var event = req.headers['x-codeup-event']

    if (!event) {
      return hasError('No X-Codeup-Event found on request')
    }

    if (events && events.indexOf(event) === -1) {
      return hasError('X-Codeup-Event is not acceptable')
    }
    const { body } = req

    let payload

    try {
      payload = JSON.parse(body.toString())
    } catch (e) {
      return hasError(e)
    }

    if (this.options.secret) {
      if (!verify(req.headers['x-codeup-token'], this.options.secret)) {
        return hasError('secret does not match')
      }
    }

    const data = {
      event,
      payload,
      protocol: req.protocol,
      host: req.headers['host'],
      url: req.url,
      path: req.path,
    }
    return data
  }
}

module.exports = (options) => new Codeup(options)
