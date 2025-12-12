<template>
    <div class="signin-background">
        <AppPage :return-url="returnUrl" />
    </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { usePage } from '@inertiajs/vue3';
import AppPage from './AppPage.vue';

const page = usePage();

const returnUrl = computed(() => {
    return (page.props as any).returnUrl as string | undefined;
});
</script>

<style scoped>
/* Additional scoped styles if needed */
</style>