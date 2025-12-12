import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import { router } from '@inertiajs/vue3';

interface User {
    id: string;
    username: string;
    displayName: string;
    email: string;
    roles: string[];
}

export const useAuthStore = defineStore('auth', () => {
    // State
    const user = ref<User | null>(null);
    const token = ref<string | null>(null);
    const loading = ref(false);
    const error = ref<string | null>(null);

    // Getters
    const isAuthenticated = computed(() => !!user.value && !!token.value);
    const isAdmin = computed(() => user.value?.roles.includes('Admin') ?? false);
    const isEditor = computed(() =>
        user.value?.roles.some(role => ['Admin', 'Editor'].includes(role)) ?? false
    );

    // Actions
    async function login(username: string, password: string, returnUrl: string | null = null) {
        loading.value = true;
        error.value = null;

        try {
            // เรียก ServiceStack Authentication API
            const response = await fetch('/auth/credentials', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    userName: username,
                    password: password,
                    rememberMe: true
                }),
                credentials: 'include',
            });

            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(errorData.responseStatus?.message || 'การเข้าสู่ระบบล้มเหลว');
            }

            const data = await response.json();

            // ตั้งค่า user และ token
            user.value = {
                id: data.userId || data.sessionId,
                username: data.userName || username,
                displayName: data.displayName || username,
                email: data.email || '',
                roles: data.roles || []
            };

            token.value = data.sessionId || data.bearerToken;

            if (token.value) {
                sessionStorage.setItem('authToken', token.value);
                sessionStorage.setItem('authUser', JSON.stringify(user.value));
            }

            // Redirect
            const destination = returnUrl || '/rss';
            router.visit(destination);

        } catch (err) {
            console.error('Login error:', err);
            error.value = err instanceof Error ? err.message : 'เกิดข้อผิดพลาดในการเข้าสู่ระบบ';

            // Clear any partial state
            user.value = null;
            token.value = null;
        } finally {
            loading.value = false;
        }
    }

    async function logout() {
        loading.value = true;
        error.value = null;

        try {
            await fetch('/auth/logout', {
                method: 'POST',
                credentials: 'include',
            });
        } catch (err) {
            console.error('Logout error:', err);
        } finally {
            user.value = null;
            token.value = null;
            sessionStorage.removeItem('authToken');
            sessionStorage.removeItem('authUser');
            loading.value = false;
            router.visit('/rss/signin');
        }
    }

    async function reauthenticate() {
        const savedToken = sessionStorage.getItem('authToken');
        const savedUser = sessionStorage.getItem('authUser');

        if (!savedToken || !savedUser) {
            return;
        }

        loading.value = true;
        error.value = null;

        try {
            // ตรวจสอบ session ยังใช้งานได้หรือไม่
            const response = await fetch('/auth/check', {
                headers: {
                    'Authorization': `Bearer ${savedToken}`,
                },
                credentials: 'include',
            });

            if (response.ok) {
                user.value = JSON.parse(savedUser);
                token.value = savedToken;
            } else {
                throw new Error('Session expired');
            }
        } catch (err) {
            console.error('Reauthentication error:', err);
            sessionStorage.removeItem('authToken');
            sessionStorage.removeItem('authUser');
            user.value = null;
            token.value = null;
        } finally {
            loading.value = false;
        }
    }

    function clearError() {
        error.value = null;
    }

    return {
        user,
        token,
        loading,
        error,
        isAuthenticated,
        isAdmin,
        isEditor,
        login,
        logout,
        reauthenticate,
        clearError,
    };
});