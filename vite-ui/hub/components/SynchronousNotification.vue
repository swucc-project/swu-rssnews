<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue';
import { emitter } from '~tools/emitter';

interface Notification {
  id: number;
  message: string;
  type: string;
}

const notifications = ref<Notification[]>([]);

const handler = (payload: { message: string; type: string }) => {
  const notification: Notification = {
    id: Date.now(),
    message: payload.message,
    type: payload.type
  };
  
  notifications.value.push(notification);
  
  setTimeout(() => {
    const index = notifications.value.findIndex(n => n.id === notification.id);
    if (index > -1) {
      notifications.value.splice(index, 1);
    }
  }, 5000);
};

onMounted(() => {
  emitter.on('new-notification', handler);
});

onUnmounted(() => {
  emitter.off('new-notification', handler);
});

const getAlertClass = (type: string) => {
  const classes: Record<string, string> = {
    success: 'alert-success',
    error: 'alert-error',
    warning: 'alert-warning',
    info: 'alert-info'
  };
  return classes[type] || 'alert-info';
};

const getIcon = (type: string) => {
  const icons: Record<string, string> = {
    success: 'M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z',
    error: 'M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z',
    warning: 'M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z',
    info: 'M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z'
  };
  return icons[type] || icons.info;
};
</script>

<template>
  <div class="notification-container">
    <TransitionGroup name="notification" tag="div" class="notification-list">
      <div 
        v-for="notification in notifications" 
        :key="notification.id"
        class="alert shadow-lg mb-3"
        :class="getAlertClass(notification.type)"
      >
        <div class="flex items-start gap-3 w-full">
          <svg 
            xmlns="http://www.w3.org/2000/svg" 
            class="stroke-current flex-shrink-0 h-6 w-6" 
            fill="none" 
            viewBox="0 0 24 24"
          >
            <path 
              stroke-linecap="round" 
              stroke-linejoin="round" 
              stroke-width="2" 
              :d="getIcon(notification.type)"
            />
          </svg>
          <span>{{ notification.message }}</span>
        </div>
      </div>
    </TransitionGroup>
  </div>
</template>

<style scoped>
.notification-container {
  position: fixed;
  top: 1rem;
  right: 1rem;
  z-index: 9999;
  max-width: 400px;
}

.notification-list {
  display: flex;
  flex-direction: column;
}

.notification-enter-active,
.notification-leave-active {
  transition: all 0.3s ease;
}

.notification-enter-from {
  opacity: 0;
  transform: translateX(100%);
}

.notification-leave-to {
  opacity: 0;
  transform: translateX(100%);
}

@media (max-width: 640px) {
  .notification-container {
    left: 1rem;
    right: 1rem;
    max-width: none;
  }
}
</style>