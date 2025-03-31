import axios from "axios";
import get from "lodash.get";

export interface Env {
  WECHAT_BOT_KEY: string;
  SENIVERSE_KEY: string;
  WEATHER_CITY: string;
}

export default async (env: Env) => {
  try {
    const _now = await getWeatherNow(env);
    const now = get(_now, "results[0].now");
    const weather = await getWeather(env);
    const today = get(weather, "results[0].daily[0]");
    const tomorrow = get(weather, "results[0].daily[1]");

    const { hitokoto } = await getHitokoto();

    const advice = today.text_day?.includes("雨")
      ? "今日有雨，出门记得带伞☂。"
      : "";
    const news = {
      msgtype: "news",
      news: {
        articles: [
          {
            title: `天气播报：${now.text}${
              now.text.includes("雨") ? "⛆" : now.text === "晴" ? "☀" : ""
            }  ${now.temperature}℃`,
            description: `今天: ${today.text_day}${
              today.text_day !== today.text_night ? "转" + today.text_night : ""
            }, ${today.low}℃ - ${today.high}℃, ${today.wind_direction}风 ${
              today.wind_scale
            }级。${advice}\n明天: ${tomorrow.text_day}, ${tomorrow.low}℃ - ${
              tomorrow.high
            }℃, ${today.wind_direction}风 ${
              today.wind_scale
            }级。 \n*数据来源: 心知天气\n\n每日一言：${hitokoto}`,
            url: "https://docs.emooa.com",
            picurl: `https://api.emooa.com/aimg?time=${Date.now()}`,
          },
        ],
      },
    };
    await rebot(env, news);
  } catch (e: any) {
    await rebot(env, {
      msgtype: "text",
      text: {
        content: `天气播报失败: ${e.message}`,
        mentioned_list: ["黄福山"],
        mentioned_mobile_list: ["13161111366"],
      },
    });
    return e.message;
  }
};

const getWeatherNow = async (env: Env) => {
  const response = await axios({
    method: "get",
    url: "https://api.seniverse.com/v3/weather/now.json",
    params: {
      key: env.SENIVERSE_KEY,
      location: env.WEATHER_CITY,
      language: "zh-Hans",
      unit: "c",
    },
  });
  return response.data;
};

const getWeather = async (env: Env) => {
  const response = await axios({
    method: "get",
    url: "https://api.seniverse.com/v3/weather/daily.json",
    params: {
      key: env.SENIVERSE_KEY,
      location: env.WEATHER_CITY,
      language: "zh-Hans",
      unit: "c",
      start: 0,
      days: 2,
    },
  });
  return response.data;
};

const getHitokoto = async () => {
  const response = await axios({
    method: "get",
    url: "https://v1.hitokoto.cn/",
  });
  return response.data;
};

const rebot = async (env: Env, news: object) => {
  const response = await axios({
    method: "post",
    url: "https://qyapi.weixin.qq.com/cgi-bin/webhook/send",
    data: news,
    params: {
      key: env.WECHAT_BOT_KEY,
    },
  });

  return response.data;
};
