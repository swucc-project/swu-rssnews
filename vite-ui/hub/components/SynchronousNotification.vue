<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue';
import { emitter } from '~tools/emitter'; // Import event bus ของเรา

type Notification = {
  id: number;
  message: string;
  type: 'success' | 'info' | 'warning' | 'error';
};

const notifications = ref<Notification[]>([]);

const addNotification = (payload: Notification) => {
  notifications.value.push(payload);
  // ตั้งเวลาลบ notification ออกจากจอหลังจาก 5 วินาที
  setTimeout(() => removeNotification(payload.id), 5000);
};

const removeNotification = (id: number) => {
  notifications.value = notifications.value.filter(n => n.id !== id);
};

onMounted(() => {
  // เริ่มฟัง event `new-notification`
  emitter.on('new-notification', (payload) => {
    addNotification({ ...payload, id: Date.now() });
  });
});

onUnmounted(() => {
  // หยุดฟัง event เมื่อคอมโพเนนต์ถูกทำลายเพื่อป้องกัน memory leak
  emitter.off('new-notification');
});

// Map type ไปยัง class ของ DaisyUI
const alertClasses = {
  success: 'alert-success',
  info: 'alert-info',
  warning: 'alert-warning',
  error: 'alert-error',
};
</script>

<template>
  <!-- Container สำหรับการแจ้งเตือนทั้งหมด, ตำแหน่ง fixed ที่มุมขวาบน -->
  <div class="toast toast-top toast-end z-50 font-sarabun">
    <TransitionGroup name="list">
      <div 
        v-for="notification in notifications" 
        :key="notification.id"
        class="alert shadow-lg"
        :class="alertClasses[notification.type]"
      >
        <div>
          <span>{{ notification.message }}</span>
        </div>
      </div>
    </TransitionGroup>
  </div>
</template>

<style scoped>
/* Transition สำหรับการเพิ่ม/ลบ item */
.list-enter-active,
.list-leave-active {
  transition: all 0.5s ease;
}
.list-enter-from,
.list-leave-to {
  opacity: 0;
  transform: translateX(30px);
}
</style>