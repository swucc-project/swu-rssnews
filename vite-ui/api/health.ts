import { apiClient } from '~api/web-client';

export const healthService = {
    /**
     * ตรวจสอบสถานะของระบบ
     */
    async checkHealth() {
        try {
            const response = await apiClient.api.healthControllerGetHealth();
            return response.data;
        } catch (error) {
            console.error('Health check failed:', error);
            throw error;
        }
    },

    /**
     * ตรวจสอบสถานะฐานข้อมูล
     */
    async checkDatabase() {
        try {
            const response = await apiClient.api.healthControllerGetDatabaseHealth();
            return response.data;
        } catch (error) {
            console.error('Database health check failed:', error);
            throw error;
        }
    },
};