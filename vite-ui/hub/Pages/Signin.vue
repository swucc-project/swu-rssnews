<template>
    <div class="signin-background">
        <AppPage :return-url="returnUrl" />
    </div>
</template>

<script setup lang="ts">
import { computed, watch } from 'vue';
import { usePage, router } from '@inertiajs/vue3';
import { useAuthStore } from '@hub/stores/auth'
import IdentityLayout from '@components/layouts/IdentityLayout.vue'
import AppPage from './AppPage.vue';

defineOptions({
    layout: IdentityLayout
})

const page = usePage();

const authStore = useAuthStore();

const returnUrl = computed(() => {
    return (page.props as any).returnUrl as string | undefined;
});

watch(
    () => authStore.isAuthenticated.value,
    (isAuth) => {
        if (isAuth) {
            router.visit(returnUrl.value || '/rss/add');
        }
    },
    { immediate: true }
);
</script>

<style scoped>
/* Additional scoped styles if needed */
</style>