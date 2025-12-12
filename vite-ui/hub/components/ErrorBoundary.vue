<script setup lang="ts">
import { ref, onErrorCaptured } from 'vue';

const hasError = ref(false);

onErrorCaptured((error, vm, info) => {
  console.error('ErrorBoundary caught an error:', error, info);
  hasError.value = true;
  // คืนค่า true เพื่อป้องกันไม่ให้ error ถูกส่งต่อไปยัง parent component อื่นๆ
  return true; 
});
</script>

<template>
  <div v-if="hasError" class="p-4 font-sarabun">
    <div class="alert alert-error shadow-lg">
      <div>
        <svg xmlns="http://www.w3.org/2000/svg" class="stroke-current flex-shrink-0 h-6 w-6" fill="none" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
        <span>มีบางอย่างผิดปกติ!</span>
      </div>
      <div class="flex-none">
        <button class="btn btn-sm" @click="() => hasError = false">ลองอีกครั้ง</button>
      </div>
    </div>
    <p class="mt-2 text-sm text-gray-600">
      เกิดข้อผิดพลาดในการแสดงผลคอมโพเนนต์ส่วนนี้ กรุณาลองใหม่อีกครั้ง หรือติดต่อผู้ดูแลระบบ
    </p>
  </div>
  <slot v-else></slot>
</template>