import { createApp, createMetricsRegistry } from "./app.js";

const port = Number(process.env.PORT ?? 3000);
const startedAt = new Date();

const app = createApp({
  metrics: createMetricsRegistry(),
  now: () => new Date(),
  startedAt
});

app.listen(port, "0.0.0.0", () => {
  console.log(`backend running on port ${port}`);
});
