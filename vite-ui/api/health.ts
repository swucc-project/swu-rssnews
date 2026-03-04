// ✅ Health Service API
const API_BASE = import.meta.env.VITE_PUBLIC_API_URL || '';

interface HealthResponse {
    status: string;
    timestamp?: string;
    uptime?: number;
    uptimeFormatted?: string;
    environment?: string;
    database?: string;
    cached?: boolean;
}

interface DetailedHealthResponse {
    status: string;
    timestamp: string;
    version: string;
    checks: {
        database: {
            status: string;
            provider?: string;
            itemCount?: number;
            responseTimeMs?: number;
            error?: string;
        };
        graphql: { status: string; endpoint: string };
        grpc: { status: string; endpoint: string };
        system: {
            uptime: number;
            uptimeFormatted: string;
            memoryMB: number;
            cpuCount: number;
            processId: number;
        };
    };
}

export const healthService = {
    // ✅ Basic health check (liveness)
    async checkHealth(): Promise<HealthResponse> {
        const response = await fetch(`${API_BASE}/health`, {
            method: 'GET',
            headers: { 'Accept': 'application/json' },
            // ✅ Short timeout for health checks
            signal: AbortSignal.timeout(5000),
        });

        if (!response.ok) {
            throw new Error(`Health check failed: ${response.status}`);
        }

        return response.json();
    },

    // ✅ Readiness check (includes database)
    async checkReady(): Promise<HealthResponse> {
        const response = await fetch(`${API_BASE}/health/ready`, {
            method: 'GET',
            headers: { 'Accept': 'application/json' },
            signal: AbortSignal.timeout(10000),
        });

        if (!response.ok) {
            throw new Error(`Readiness check failed: ${response.status}`);
        }

        return response.json();
    },

    // ✅ Detailed health for monitoring
    async checkDetailed(): Promise<DetailedHealthResponse> {
        const response = await fetch(`${API_BASE}/health/detailed`, {
            method: 'GET',
            headers: { 'Accept': 'application/json' },
            signal: AbortSignal.timeout(15000),
        });

        if (!response.ok) {
            throw new Error(`Detailed health check failed: ${response.status}`);
        }

        return response.json();
    },

    // ✅ GraphQL health check
    async checkGraphQL(): Promise<{ status: string; endpoint: string }> {
        const response = await fetch(`${API_BASE}/health/graphql`, {
            method: 'GET',
            headers: { 'Accept': 'application/json' },
        });

        return response.json();
    }
};