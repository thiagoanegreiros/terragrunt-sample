const router = {
  "GET /health": () => ({ status: "ok" }),
  "GET /hello": (event) => {
    const name = event.queryStringParameters?.name ?? "world";
    return { message: `Hello, ${name}!` };
  },
};

exports.handler = async (event) => {
  const key = `${event.requestContext.http.method} ${event.requestContext.http.path}`;
  const handler = router[key];

  if (!handler) {
    return respond(404, { error: "Not found" });
  }

  try {
    const body = handler(event);
    return respond(200, body);
  } catch (err) {
    console.error(err);
    return respond(500, { error: "Internal server error" });
  }
};

function respond(statusCode, body) {
  return {
    statusCode,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  };
}
