import { ref, onMounted } from 'vue';
import { healthService } from '~api/health';

export function deployHealthCheck() {
    const isHealthy = ref<boolean>(false);
    const loading = ref<boolean>(false);
    const error = ref<Error | null>(null);
    const lastCheck = ref<Date | null>(null);

    const checkHealth = async () => {
        loading.value = true;
        error.value = null;

        try {
            const result = await healthService.checkHealth();
            isHealthy.value = result.status === 'Healthy';
            lastCheck.value = new Date();
        } catch (err) {
            error.value = err instanceof Error ? err : new Error('Unknown error');
            isHealthy.value = false;
        } finally {
            loading.value = false;
        }
    };

    onMounted(() => {
        checkHealth();
        // ตรวจสอบทุก 5 นาที
        setInterval(checkHealth, 5 * 60 * 1000);
    });

    return {
        isHealthy,
        loading,
        error,
        lastCheck,
        checkHealth,
    };
}