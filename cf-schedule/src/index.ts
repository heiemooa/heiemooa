/// <reference types="@cloudflare/workers-types" />
import weather, { Env } from "./weather";

export default {
  async scheduled(
    event: ScheduledEvent,
    env: Env,
    ctx: ExecutionContext
  ): Promise<void> {
    const currentTime = new Date(event.scheduledTime);
    const hourUTC = currentTime.getUTCHours();
    const minuteUTC = currentTime.getUTCMinutes();

    if (
      (hourUTC === 1 && minuteUTC === 0) ||
      (hourUTC === 10 && minuteUTC === 0)
    ) {
      ctx.waitUntil(
        weather(env).then((result) => {
          console.log(result);
          return result;
        })
      );
    }
  },

  async fetch(
    request: Request,
    env: Env,
    ctx: ExecutionContext
  ): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/weather") {
      const data = await weather(env);
      return new Response(data || "推送已触发！");
    }

    return new Response("请访问 /weather 手动触发", { status: 404 });
  },
};
