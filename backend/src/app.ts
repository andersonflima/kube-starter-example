import cors from "cors";
import express from "express";

type AppDependencies = {
  readonly now: () => Date;
  readonly startedAt: Date;
};

type HealthResponse = {
  readonly service: "backend";
  readonly status: "ok";
  readonly timestamp: string;
};

type MessageResponse = {
  readonly title: string;
  readonly description: string;
  readonly version: string;
  readonly timestamp: string;
};

type StatsResponse = {
  readonly nodeVersion: string;
  readonly platform: NodeJS.Platform;
  readonly uptimeInSeconds: number;
  readonly startedAt: string;
};

const toIsoString = (value: Date): string => value.toISOString();

const toUptimeInSeconds = (startedAt: Date, currentTime: Date): number =>
  Math.max(0, Math.floor((currentTime.getTime() - startedAt.getTime()) / 1000));

const buildHealthResponse = ({ now }: AppDependencies): HealthResponse => ({
  service: "backend",
  status: "ok",
  timestamp: toIsoString(now())
});

const buildMessageResponse = ({ now }: AppDependencies): MessageResponse => ({
  title: "Kube Starter",
  description: "Backend simples com frontend e deploy pronto para Kubernetes.",
  version: "1.0.0",
  timestamp: toIsoString(now())
});

const buildStatsResponse = ({ now, startedAt }: AppDependencies): StatsResponse => {
  const currentTime = now();

  return {
    nodeVersion: process.version,
    platform: process.platform,
    uptimeInSeconds: toUptimeInSeconds(startedAt, currentTime),
    startedAt: toIsoString(startedAt)
  };
};

export const createApp = (dependencies: AppDependencies) => {
  const app = express();

  app.use(cors());
  app.use(express.json());

  app.get("/api/health", (_request, response) => {
    response.json(buildHealthResponse(dependencies));
  });

  app.get("/api/message", (_request, response) => {
    response.json(buildMessageResponse(dependencies));
  });

  app.get("/api/stats", (_request, response) => {
    response.json(buildStatsResponse(dependencies));
  });

  return app;
};

