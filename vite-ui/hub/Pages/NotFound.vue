<template>
  <div class="min-h-screen flex items-center justify-center bg-gray-50 dark:bg-gray-900">
    <div class="max-w-md w-full space-y-8 p-8 bg-white dark:bg-gray-800 rounded-lg shadow-lg text-center">
      <!-- Icon -->
      <div class="flex justify-center">
        <div class="rounded-full bg-red-100 dark:bg-red-900/20 p-6">
          <svg
            class="h-16 w-16 text-red-600 dark:text-red-400"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
            />
          </svg>
        </div>
      </div>

      <!-- Title -->
      <div>
        <h1 class="text-4xl font-bold text-gray-900 dark:text-white mb-2 font-sarabun">
          404
        </h1>
        <h2 class="text-xl font-semibold text-gray-700 dark:text-gray-300 mb-2 font-sarabun">
          ไม่พบหน้าที่ต้องการ
        </h2>
        <p class="text-gray-600 dark:text-gray-400 font-sarabun">
          {{ message }}
        </p>
      </div>

      <!-- Actions -->
      <div class="space-y-3">
        <Link
          href="/rss"
          class="w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 transition-colors font-sarabun"
        >
          กลับหน้าหลัก
        </Link>
        
        <button
          @click="goBack"
          class="w-full flex justify-center py-2 px-4 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm text-sm font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-700 hover:bg-gray-50 dark:hover:bg-gray-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 transition-colors font-sarabun"
        >
          ย้อนกลับ
        </button>
      </div>

      <!-- Additional info in development -->
      <div v-if="isDev" class="mt-6 p-4 bg-yellow-50 dark:bg-yellow-900/20 rounded-md text-left">
        <p class="text-xs font-mono text-gray-600 dark:text-gray-400">
          Path: {{ currentPath }}
        </p>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { Link, router } from '@inertiajs/vue3';

const isDev = computed(() => import.meta.env.DEV);
const currentPath = computed(() => {
  if (typeof window !== 'undefined') {
    return window.location.pathname;
  }
  return '';
});

const message = computed(() => {
  return 'ขออภัย เราไม่พบหน้าที่คุณต้องการ กรุณาตรวจสอบ URL หรือกลับไปที่หน้าหลัก';
});

function goBack() {
  // Check if there's history to go back to
  if (typeof window !== 'undefined' && window.history.length > 1) {
    window.history.back();
  } else {
    router.visit('/rss');
  }
}
</script>

<style scoped>
/* Additional styles if needed */
</style>