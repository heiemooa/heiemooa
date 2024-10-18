const clientID = "dbfb2ff36c6e69d4e3c6";
const clientSecret = "d42fb0fdddef9325ab902f6fce030c1da6497f77";

const Koa = require("koa");
const path = require("path");
const serve = require("koa-static");
const route = require("koa-route");
const axios = require("axios");

const app = new Koa();

const main = serve(path.join(__dirname + "/public"));

const oauth = async (ctx) => {
  const requestToken = ctx.request.query.code;

  console.log("authorization code:", requestToken);

  const tokenResponse = await axios({
    method: "post",
    url:
      "https://github.com/login/oauth/access_token?" +
      `client_id=${clientID}&` +
      `client_secret=${clientSecret}&` +
      `code=${requestToken}`,
    headers: {
      accept: "application/json",
    },
  });

  const accessToken = tokenResponse.data.access_token;
  console.log(`access token: ${accessToken}`);

  const result = await axios({
    method: "get",
    url: `https://api.github.com/user`,
    headers: {
      accept: "application/json",
      Authorization: `token ${accessToken}`,
    },
  });

  const name = result.data.name;

  ctx.response.redirect(`/welcome.html?token=${accessToken}`);
};

app.use(main);
app.use(route.get("/oauth/redirect", oauth));

app.listen(8080);
