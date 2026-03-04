import { ref, onMounted, onUnmounted } from 'vue';
import { healthService } from '~api/health';

// ✅ Type definitions
interface HealthStatus {
    status: 'Healthy' | 'Unhealthy' | 'Degraded' | 'Starting';
    timestamp?: string;
    uptime?: number;
    uptimeFormatted?: string;
    database?: string;
    environment?: string;
}

interface HealthCheckResult {
    isHealthy: Ref<boolean>;
    status: Ref<HealthStatus | null>;
    loading: Ref<boolean>;
    error: Ref<Error | null>;
    lastCheck: Ref<Date | null>;
    checkHealth: () => Promise<void>;
    startAutoCheck: (intervalMs?: number) => void;
    stopAutoCheck: () => void;
}

export function deployHealthCheck(autoStart: boolean = true): HealthCheckResult {
    const isHealthy = ref<boolean>(false);
    const status = ref<HealthStatus | null>(null);
    const loading = ref<boolean>(false);
    const error = ref<Error | null>(null);
    const lastCheck = ref<Date | null>(null);

    let intervalId: ReturnType<typeof setInterval> | null = null;
    let retryCount = 0;
    const maxRetries = 3;

    const checkHealth = async (): Promise<void> => {
        // ✅ ป้องกันการเรียกซ้ำขณะ loading
        if (loading.value) return;

        loading.value = true;
        error.value = null;

        try {
            const result = await healthService.checkHealth();

            // ✅ ตรวจสอบ status ที่ถูกต้อง (รองรับทั้ง PascalCase และ lowercase)
            const healthyStatuses = ['Healthy', 'healthy', 'ok', 'OK'];
            isHealthy.value = healthyStatuses.includes(result.status);
            status.value = result;
            lastCheck.value = new Date();
            retryCount = 0; // Reset retry count on success

        } catch (err) {
            error.value = err instanceof Error ? err : new Error('Unknown error');
            isHealthy.value = false;
            status.value = null;

            // ✅ Exponential backoff retry
            retryCount++;
            if (retryCount <= maxRetries) {
                const delay = Math.min(1000 * Math.pow(2, retryCount), 30000);
                console.warn(`Health check failed, retry ${retryCount}/${maxRetries} in ${delay}ms`);
                setTimeout(checkHealth, delay);
            }
        } finally {
            loading.value = false;
        }
    };

    const startAutoCheck = (intervalMs: number = 5 * 60 * 1000): void => {
        stopAutoCheck(); // ✅ ป้องกัน multiple intervals
        intervalId = setInterval(checkHealth, intervalMs);
    };

    const stopAutoCheck = (): void => {
        if (intervalId) {
            clearInterval(intervalId);
            intervalId = null;
        }
    };

    onMounted(() => {
        if (autoStart) {
            checkHealth();
            startAutoCheck();
        }
    });

    // ✅ Cleanup on unmount
    onUnmounted(() => {
        stopAutoCheck();
    });

    return {
        isHealthy,
        status,
        loading,
        error,
        lastCheck,
        checkHealth,
        startAutoCheck,
        stopAutoCheck,
    };
}

// ✅ Composable สำหรับ detailed health check
export function deployDetailedHealthCheck() {
    const data = ref<any>(null);
    const loading = ref(false);
    const error = ref<Error | null>(null);

    const checkDetailedHealth = async () => {
        loading.value = true;
        try {
            const response = await fetch('/health/detailed');
            data.value = await response.json();
        } catch (err) {
            error.value = err instanceof Error ? err : new Error('Failed to fetch detailed health');
        } finally {
            loading.value = false;
        }
    };

    return { data, loading, error, checkDetailedHealth };
}