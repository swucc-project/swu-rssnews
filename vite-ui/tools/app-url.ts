/**
 * Application URL Configuration
 * ใช้สำหรับ get base URL ของ frontend
 * 
 * Environment Variables Priority:
 * 1. VITE_APP_URL (primary - from docker-compose)
 * 2. APP_URL (fallback 1)
 * 3. FRONTEND_URL (fallback 2)
 * 4. VITE_PUBLIC_API_URL (legacy support)
 * 5. window.location.origin (last resort)
 */

// ✅ Type definitions
export interface EnvInfo {
    mode: string;
    appUrl: string;
    apiUrl: string | undefined;
    graphqlUrl: string | undefined;
    wsUrl: string | undefined;
    grpcUrl: string | undefined;
    isDev: boolean;
    isProd: boolean;
}

// ✅ Get configured APP_URL with proper fallback chain
export const getAppUrl = (): string => {
    // Priority order:
    // 1. VITE_APP_URL (set from docker-compose)
    if (import.meta.env.VITE_APP_URL) {
        return import.meta.env.VITE_APP_URL;
    }

    // 2. APP_URL (alternative)
    if (import.meta.env.APP_URL) {
        return import.meta.env.APP_URL;
    }

    // 3. FRONTEND_URL (alternative)
    if (import.meta.env.FRONTEND_URL) {
        return import.meta.env.FRONTEND_URL;
    }

    // 4. VITE_PUBLIC_API_URL (legacy support)
    if (import.meta.env.VITE_PUBLIC_API_URL) {
        return import.meta.env.VITE_PUBLIC_API_URL;
    }

    // 5. Fallback to current origin
    return window.location.origin;
};

/**
 * Get API URL (for server-side calls)
 */
export const getApiUrl = (): string => {
    return import.meta.env.VITE_PUBLIC_API_URL || getAppUrl();
};

/**
 * Get GraphQL endpoint URL
 */
export const getGraphQLUrl = (): string => {
    return import.meta.env.VITE_PUBLIC_GRAPHQL_ENDPOINT || `${getApiUrl()}/graphql`;
};

/**
 * Get WebSocket URL for GraphQL subscriptions
 */
export const getGraphQLWsUrl = (): string => {
    const wsUrl = import.meta.env.VITE_PUBLIC_GRAPHQL_WS_URL;
    if (wsUrl) return wsUrl;

    // Convert http/https to ws/wss
    const baseUrl = getApiUrl();
    const wsProtocol = baseUrl.startsWith('https') ? 'wss' : 'ws';
    const urlWithoutProtocol = baseUrl.replace(/^https?:\/\//, '');
    return `${wsProtocol}://${urlWithoutProtocol}/graphql-ws`;
};

/**
 * Get gRPC endpoint URL
 */
export const getGrpcUrl = (): string => {
    return import.meta.env.VITE_PUBLIC_GRPC_ENDPOINT || `${getApiUrl()}/grpc`;
};

/**
 * Build a full URL from a path
 * @param path - relative path (e.g., '/api/news')
 * @param useAppUrl - use APP_URL instead of API_URL (default: true)
 */
export const buildUrl = (path: string, useAppUrl = true): string => {
    const baseUrl = useAppUrl ? getAppUrl() : getApiUrl();
    const cleanPath = path.startsWith('/') ? path : `/${path}`;
    return `${baseUrl}${cleanPath}`;
};

/**
 * Build API URL
 */
export const buildApiUrl = (path: string): string => {
    return buildUrl(path, false);
};

/**
 * Check if we're in development mode
 */
export const isDevelopment = (): boolean => {
    return import.meta.env.MODE === 'development';
};

/**
 * Check if we're in production mode
 */
export const isProduction = (): boolean => {
    return import.meta.env.MODE === 'production';
};

/**
 * Check if running in Docker
 */
export const isDocker = (): boolean => {
    return import.meta.env.DOCKER_CONTAINER === 'true' ||
        import.meta.env.IS_DOCKER === 'true';
};

/**
 * Get complete environment info
 */
export const getEnvInfo = (): EnvInfo => {
    return {
        mode: import.meta.env.MODE,
        appUrl: getAppUrl(),
        apiUrl: getApiUrl(),
        graphqlUrl: getGraphQLUrl(),
        wsUrl: getGraphQLWsUrl(),
        grpcUrl: getGrpcUrl(),
        isDev: isDevelopment(),
        isProd: isProduction(),
    };
};

/**
 * Print environment configuration (for debugging)
 */
export const printEnvConfig = (): void => {
    if (!isDevelopment()) return;

    const info = getEnvInfo();
    console.group('🔧 Environment Configuration');
    console.log('Mode:', info.mode);
    console.log('APP_URL:', info.appUrl);
    console.log('API_URL:', info.apiUrl);
    console.log('GraphQL:', info.graphqlUrl);
    console.log('WebSocket:', info.wsUrl);
    console.log('gRPC:', info.grpcUrl);
    console.log('Is Docker:', isDocker());
    console.groupEnd();
};

/**
 * Validate configuration
 */
export const validateConfig = (): { valid: boolean; errors: string[] } => {
    const errors: string[] = [];

    // Check APP_URL
    const appUrl = getAppUrl();
    if (!appUrl || appUrl === window.location.origin) {
        errors.push('APP_URL not configured, using fallback');
    }

    // Check API_URL in production
    if (isProduction()) {
        const apiUrl = getApiUrl();
        if (!apiUrl.startsWith('https')) {
            errors.push('API_URL should use HTTPS in production');
        }
    }

    return {
        valid: errors.length === 0,
        errors
    };
};

// ✅ Auto-print config in development
if (isDevelopment() && typeof window !== 'undefined') {
    printEnvConfig();

    const validation = validateConfig();
    if (!validation.valid) {
        console.warn('⚠️ Configuration warnings:', validation.errors);
    }
}

// Export as default for convenience
export default {
    getAppUrl,
    getApiUrl,
    getGraphQLUrl,
    getGraphQLWsUrl,
    getGrpcUrl,
    buildUrl,
    buildApiUrl,
    isDevelopment,
    isProduction,
    isDocker,
    getEnvInfo,
    printEnvConfig,
    validateConfig,
};