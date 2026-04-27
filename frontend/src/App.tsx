import { useEffect, useState } from "react";

type HealthResponse = {
  readonly service: string;
  readonly status: string;
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
  readonly platform: string;
  readonly uptimeInSeconds: number;
  readonly startedAt: string;
};

type ApiState = {
  readonly health: HealthResponse | null;
  readonly message: MessageResponse | null;
  readonly stats: StatsResponse | null;
  readonly isLoading: boolean;
  readonly error: string | null;
};

const initialState: ApiState = {
  health: null,
  message: null,
  stats: null,
  isLoading: true,
  error: null
};

const requestJson = async <T,>(path: string): Promise<T> => {
  const response = await fetch(path);

  if (!response.ok) {
    throw new Error(`request failed for ${path}`);
  }

  return response.json() as Promise<T>;
};

const App = () => {
  const [state, setState] = useState<ApiState>(initialState);

  useEffect(() => {
    const load = async () => {
      try {
        const [health, message, stats] = await Promise.all([
          requestJson<HealthResponse>("/api/health"),
          requestJson<MessageResponse>("/api/message"),
          requestJson<StatsResponse>("/api/stats")
        ]);

        setState({
          health,
          message,
          stats,
          isLoading: false,
          error: null
        });
      } catch (error) {
        setState({
          health: null,
          message: null,
          stats: null,
          isLoading: false,
          error: error instanceof Error ? error.message : "unexpected error"
        });
      }
    };

    void load();
  }, []);

  return (
    <main className="page-shell">
      <section className="hero">
        <div className="hero__copy">
          <span className="hero__eyebrow">Cluster-ready starter</span>
          <h1>Kube Starter</h1>
          <p>
            Backend simples, frontend conectado e empacotamento pronto para rodar com
            Docker e Kubernetes.
          </p>
          <div className="hero__actions">
            <a href="#endpoints">Ver endpoints</a>
            <span>Helm + Compose + TypeScript</span>
          </div>
        </div>
        <div className="hero__signal">
          <div>
            <strong>{state.health?.status ?? (state.isLoading ? "loading" : "offline")}</strong>
            <span>API status</span>
          </div>
          <div>
            <strong>{state.stats?.uptimeInSeconds ?? 0}s</strong>
            <span>Uptime</span>
          </div>
        </div>
      </section>

      <section className="status-strip" aria-label="Deployment assets">
        <span>3 endpoints</span>
        <span>React + Vite</span>
        <span>Express + TypeScript</span>
        <span>Docker Compose</span>
        <span>Helm chart</span>
      </section>

      <section className="endpoint-grid" id="endpoints">
        <article>
          <p className="endpoint-grid__label">GET /api/health</p>
          <h2>Health probe</h2>
          <p>Indica status do backend e o instante da resposta.</p>
          <dl>
            <div>
              <dt>Service</dt>
              <dd>{state.health?.service ?? "-"}</dd>
            </div>
            <div>
              <dt>Status</dt>
              <dd>{state.health?.status ?? "-"}</dd>
            </div>
            <div>
              <dt>Timestamp</dt>
              <dd>{state.health?.timestamp ?? "-"}</dd>
            </div>
          </dl>
        </article>

        <article>
          <p className="endpoint-grid__label">GET /api/message</p>
          <h2>Service summary</h2>
          <p>Entrega a mensagem principal da aplicação e sua versão.</p>
          <dl>
            <div>
              <dt>Title</dt>
              <dd>{state.message?.title ?? "-"}</dd>
            </div>
            <div>
              <dt>Version</dt>
              <dd>{state.message?.version ?? "-"}</dd>
            </div>
            <div>
              <dt>Description</dt>
              <dd>{state.message?.description ?? "-"}</dd>
            </div>
          </dl>
        </article>

        <article>
          <p className="endpoint-grid__label">GET /api/stats</p>
          <h2>Runtime stats</h2>
          <p>Mostra dados do runtime para validar o container em execução.</p>
          <dl>
            <div>
              <dt>Node</dt>
              <dd>{state.stats?.nodeVersion ?? "-"}</dd>
            </div>
            <div>
              <dt>Platform</dt>
              <dd>{state.stats?.platform ?? "-"}</dd>
            </div>
            <div>
              <dt>Started at</dt>
              <dd>{state.stats?.startedAt ?? "-"}</dd>
            </div>
          </dl>
        </article>
      </section>

      <section className="footer-panel">
        <div>
          <p className="endpoint-grid__label">Current state</p>
          <h2>{state.isLoading ? "Buscando dados da API" : "Stack operacional"}</h2>
        </div>
        <p>{state.error ?? "Frontend consumindo o backend via /api com proxy no nginx."}</p>
      </section>
    </main>
  );
};

export default App;

