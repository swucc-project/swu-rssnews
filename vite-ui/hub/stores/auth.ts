import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import { router } from '@inertiajs/vue3';
import { pushNotification } from '@hub/suites/pushNotification';

interface User {
    id: string;
    username: string;
    displayName: string;
    email: string;
    roles: string[];
}

interface AuthResponse {
    userId?: string;
    sessionId?: string;
    userName?: string;
    displayName?: string;
    email?: string;
    roles?: string[];
    bearerToken?: string;
}

export const useAuthStore = defineStore('auth', () => {
    // ✅ Get notification composable
    const notify = pushNotification();

    // ✅ State
    const user = ref<User | null>(null);
    const token = ref<string | null>(null);
    const loading = ref(false);
    const error = ref<string | null>(null);

    // ✅ Getters
    const isAuthenticated = computed(() => !!user.value && !!token.value);
    const isAdmin = computed(() => user.value?.roles.includes('Admin') ?? false);
    const isEditor = computed(() =>
        user.value?.roles.some(role => ['Admin', 'Editor'].includes(role)) ?? false
    );

    async function login(username: string, password: string, returnUrl: string | null = null) {
        if (loading.value) return;

        loading.value = true;
        error.value = null;

        try {
            const response = await fetch('/auth/credentials', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    userName: username,
                    password: password,
                    rememberMe: true
                }),
                credentials: 'include',
            });

            const data = await response.json().catch(() => ({}));

            if (!response.ok) {
                throw new Error(data?.responseStatus?.message || 'การเข้าสู่ระบบล้มเหลว');
            }

            user.value = {
                id: data.userId || data.sessionId || '',
                username: data.userName || username,
                displayName: data.displayName || username,
                email: data.email || '',
                roles: data.roles || []
            };

            const derivedToken = data.sessionId || data.bearerToken;

            if (!derivedToken) {
                throw new Error('ไม่ได้รับ token จากระบบ');
            }

            token.value = derivedToken;

            // ✅ Safe browser check
            if (typeof window !== 'undefined' && token.value) {
                sessionStorage.setItem('authToken', token.value);
                sessionStorage.setItem('authUser', JSON.stringify(user.value));
            }

            notify.success(`ยินดีต้อนรับ ${user.value.displayName}`);
            router.visit(returnUrl || '/rss/add');

        } catch (err) {
            const errorMessage = err instanceof Error ? err.message : 'เกิดข้อผิดพลาด';
            error.value = errorMessage;
            notify.error(errorMessage);
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

            // ✅ Show success notification
            notify.success('ออกจากระบบสำเร็จ');
        } catch (err) {
            console.error('Logout error:', err);
            // ✅ Still show notification even on error
            notify.info('ออกจากระบบแล้ว');
        } finally {
            user.value = null;
            token.value = null;

            // ✅ Only use sessionStorage in browser
            if (typeof window !== 'undefined') {
                sessionStorage.removeItem('authToken');
                sessionStorage.removeItem('authUser');
            }

            loading.value = false;
            router.visit('/rss/signin');
        }
    }

    async function reauthenticate() {
        // ✅ Only access sessionStorage in browser
        if (typeof window === 'undefined') {
            return;
        }

        const savedToken = sessionStorage.getItem('authToken');
        const savedUser = sessionStorage.getItem('authUser');

        if (!savedToken || !savedUser) return;

        token.value = savedToken;
        try {
            user.value = JSON.parse(savedUser);
        } catch {
            sessionStorage.removeItem('authToken');
            sessionStorage.removeItem('authUser');
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
                console.log('✅ Re-authenticated successfully');
            } else {
                throw new Error('Session expired');
            }
        } catch (err) {
            console.error('Reauthentication error:', err);
            sessionStorage.removeItem('authToken');
            sessionStorage.removeItem('authUser');
            user.value = null;
            token.value = null;

            // ✅ Only show notification if it's a real error (not just missing session)
            if (err instanceof Error && err.message !== 'Session expired') {
                notify.warning('กรุณาเข้าสู่ระบบใหม่');
            }
        } finally {
            loading.value = false;
        }
    }

    function secureAuth(currentUrl: string) {
        if (!isAuthenticated.value && !currentUrl.includes('/rss/signin')) {
            router.visit(`/rss/signin?returnUrl=${encodeURIComponent(currentUrl)}`);
            return false;
        }
        return true;
    }

    function clearError() {
        error.value = null;
    }

    function init() {
        if (typeof window === 'undefined') return;

        const savedToken = sessionStorage.getItem('authToken');
        const savedUser = sessionStorage.getItem('authUser');

        if (!savedToken || !savedUser) return;

        try {
            token.value = savedToken;
            user.value = JSON.parse(savedUser);
            console.log('✅ Auth state restored from session');
        } catch {
            sessionStorage.removeItem('authToken');
            sessionStorage.removeItem('authUser');
        }
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
        secureAuth,
        clearError,
        init,
    };
});