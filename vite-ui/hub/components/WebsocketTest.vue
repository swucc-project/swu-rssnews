<script setup lang="ts">
import { useSubscription, useMutation } from '@vue/apollo-composable';
import gql from 'graphql-tag';
import { emitter } from '~tools/emitter';
import ErrorBoundary from '@components/ErrorBoundary.vue';
import { ref, computed, watch, onMounted } from 'vue';

// ✅ FIXED: แก้ไข mutations ให้ตรงกับ GraphQL schema
// 1. เปลี่ยน ItemInput เป็น AddItemInput และ UpdateItemInput
// 2. เปลี่ยน argument จาก "item" เป็น "input"

// State
const title = ref('');
const itemIdToUpdate = ref('');
const loading = ref(false);
const events = ref<Array<{ type: string; typeClass: string; data: any }>>([]);

// ✅ Subscription: OnItemAdded (ชื่อ unique)
const { result: addedResult, error: addedError } = useSubscription(gql`
  subscription WsTestItemAdded {
    onItemAdded {
      itemID
      title
      link
      description
      publishedDate
    }
  }
`);

// ✅ Subscription: OnItemUpdated (ชื่อ unique)
const { result: updatedResult, error: updatedError } = useSubscription(gql`
  subscription WsTestItemUpdated {
    onItemUpdated {
      itemID
      title
      link
      description
      publishedDate
    }
  }
`);

// ✅ Subscription: OnItemDeleted (ชื่อ unique)
const { result: deletedResult, error: deletedError } = useSubscription(gql`
  subscription WsTestItemDeleted {
    onItemDeleted
  }
`);

// ✅ FIXED: Mutation สำหรับ addItem
// เปลี่ยนจาก: $item: ItemInput! -> $input: AddItemInput!
// เปลี่ยนจาก: addItem(item: $item) -> addItem(input: $input)
const { mutate: addItem } = useMutation(gql`
  mutation WsTestAddItem($input: AddItemInput!) {
    addItem(input: $input) {
      itemID
      title
      link
      description
      publishedDate
    }
  }
`);

// ✅ FIXED: Mutation สำหรับ updateItem
// เปลี่ยนจาก: $item: ItemInput! -> $input: UpdateItemInput!
// เปลี่ยนจาก: updateItem(id: $id, item: $item) -> updateItem(id: $id, input: $input)
const { mutate: updateItem } = useMutation(gql`
  mutation WsTestUpdateItem($id: String!, $input: UpdateItemInput!) {
    updateItem(id: $id, input: $input) {
      itemID
      title
      link
      description
      publishedDate
    }
  }
`);

const { mutate: deleteItem } = useMutation(gql`
  mutation WsTestDeleteItem($id: String!) {
    deleteRssItem(id: $id)
  }
`);

// Connection Status
const connectionStatus = computed(() => {
  if (addedError.value || updatedError.value || deletedError.value) {
    return {
      status: 'error',
      text: 'เชื่อมต่อล้มเหลว',
      class: 'badge-error'
    };
  }
  return {
    status: 'connected',
    text: 'เชื่อมต่อสำเร็จ',
    class: 'badge-success'
  };
});

// Watch subscriptions
watch(addedResult, (newValue) => {
  if (newValue?.onItemAdded) {
    events.value.unshift({
      type: '✨ ADDED',
      typeClass: 'badge badge-success',
      data: newValue.onItemAdded
    });
    emitter.emit('new-notification', {
      message: `✨ ข่าวใหม่: ${newValue.onItemAdded.title}`,
      type: 'success',
    });
  }
});

watch(updatedResult, (newValue) => {
  if (newValue?.onItemUpdated) {
    events.value.unshift({
      type: '🔄 UPDATED',
      typeClass: 'badge badge-warning',
      data: newValue.onItemUpdated
    });
    emitter.emit('new-notification', {
      message: `🔄 อัปเดต: ${newValue.onItemUpdated.title}`,
      type: 'info',
    });
  }
});

watch(deletedResult, (newValue) => {
  if (newValue?.onItemDeleted) {
    events.value.unshift({
      type: '🗑️ DELETED',
      typeClass: 'badge badge-error',
      data: { itemId: newValue.onItemDeleted }
    });
    emitter.emit('new-notification', {
      message: `🗑️ ลบแล้ว: ${newValue.onItemDeleted}`,
      type: 'warning',
    });
  }
});

// ✅ FIXED: Handlers - เปลี่ยน parameter จาก "item" เป็น "input"
const handleAddItem = async () => {
  if (!title.value) {
    emitter.emit('new-notification', {
      message: 'กรุณาใส่ชื่อข่าว',
      type: 'warning',
    });
    return;
  }

  loading.value = true;
  try {
    // เปลี่ยนจาก "item:" เป็น "input:"
    await addItem({
      input: {
        title: title.value,
        link: 'http://example.com',
        description: 'Test item created via WebSocket test',
        publishedDate: new Date().toISOString(),
      }
    });
    title.value = '';
    emitter.emit('new-notification', {
      message: '✅ สร้างข่าวสำเร็จ - รอรับ notification',
      type: 'success',
    });
  } catch (err: any) {
    console.error('Failed to add item:', err);
    emitter.emit('new-notification', {
      message: `❌ Error: ${err.message}`,
      type: 'error',
    });
  } finally {
    loading.value = false;
  }
};

const handleUpdateItem = async () => {
  if (!itemIdToUpdate.value || !title.value) {
    emitter.emit('new-notification', {
      message: 'กรุณาใส่ Item ID และชื่อข่าวใหม่',
      type: 'warning',
    });
    return;
  }

  loading.value = true;
  try {
    // เปลี่ยนจาก "item:" เป็น "input:"
    await updateItem({
      id: itemIdToUpdate.value,
      input: {
        title: title.value,
        link: 'http://example.com',
        description: 'Updated via WebSocket test',
        publishedDate: new Date().toISOString(),
      }
    });
    emitter.emit('new-notification', {
      message: '✅ อัปเดตข่าวสำเร็จ - รอรับ notification',
      type: 'success',
    });
  } catch (err: any) {
    console.error('Failed to update item:', err);
    emitter.emit('new-notification', {
      message: `❌ Error: ${err.message}`,
      type: 'error',
    });
  } finally {
    loading.value = false;
  }
};

const handleDeleteItem = async () => {
  if (!itemIdToUpdate.value) {
    emitter.emit('new-notification', {
      message: 'กรุณาใส่ Item ID',
      type: 'warning',
    });
    return;
  }

  loading.value = true;
  try {
    await deleteItem({
      id: itemIdToUpdate.value
    });
    emitter.emit('new-notification', {
      message: '✅ ลบข่าวสำเร็จ - รอรับ notification',
      type: 'success',
    });
  } catch (err: any) {
    console.error('Failed to delete item:', err);
    emitter.emit('new-notification', {
      message: `❌ Error: ${err.message}`,
      type: 'error',
    });
  } finally {
    loading.value = false;
  }
};

onMounted(() => {
  console.log('🔌 WebSocket Test component mounted');
});
</script>

<template>
  <ErrorBoundary>
    <div class="card bg-base-100 shadow-xl m-4 font-sarabun">
      <div class="card-body">
        <h2 class="card-title">📌 WebSocket Subscription Test</h2>
        
        <!-- Connection Status -->
        <div class="mt-4">
          <p class="font-semibold mb-2">สถานะการเชื่อมต่อ WebSocket:</p>
          <div :class="['badge gap-2', connectionStatus.class]">
            <span v-if="connectionStatus.status === 'connecting'" class="loading loading-spinner loading-xs"></span>
            <span>{{ connectionStatus.text }}</span>
          </div>
        </div>

        <!-- Instructions -->
        <div class="alert alert-info mt-6">
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class="stroke-current shrink-0 w-6 h-6">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
          </svg>
          <div class="text-sm">
            <p><strong>วิธีใช้:</strong></p>
            <ol class="list-decimal list-inside mt-2 space-y-1">
              <li>ตรวจสอบสถานะการเชื่อมต่อ WebSocket ด้านบน</li>
              <li><strong>สร้างข่าว:</strong> ใส่ชื่อแล้วกดปุ่ม "สร้าง"</li>
              <li><strong>อัปเดต:</strong> ใส่ Item ID และชื่อใหม่</li>
              <li><strong>ลบ:</strong> ใส่ Item ID</li>
            </ol>
          </div>
        </div>

        <!-- Test Controls -->
        <div class="mt-6 space-y-4">
          <div class="form-control">
            <label class="label">
              <span class="label-text">ชื่อข่าว</span>
            </label>
            <input v-model="title" type="text" placeholder="ใส่ชื่อข่าว" class="input input-bordered" />
          </div>

          <div class="form-control">
            <label class="label">
              <span class="label-text">Item ID (สำหรับอัปเดต/ลบ)</span>
            </label>
            <input v-model="itemIdToUpdate" type="text" placeholder="ใส่ Item ID" class="input input-bordered" />
          </div>

          <div class="flex gap-2">
            <button @click="handleAddItem" class="btn btn-primary" :disabled="loading">
              ✨ สร้าง
            </button>
            <button @click="handleUpdateItem" class="btn btn-warning" :disabled="loading">
              🔄 อัปเดต
            </button>
            <button @click="handleDeleteItem" class="btn btn-error" :disabled="loading">
              🗑️ ลบ
            </button>
          </div>
        </div>

        <!-- Subscription Results -->
        <div class="mt-6">
          <h3 class="font-semibold mb-2">📡 Subscription Events:</h3>
          <div class="bg-base-200 p-4 rounded-lg max-h-64 overflow-y-auto">
            <div v-if="events.length === 0" class="text-gray-500">
              รอรับ events...
            </div>
            <div v-for="(event, index) in events" :key="index" class="mb-2 p-2 bg-base-100 rounded">
              <span :class="event.typeClass">{{ event.type }}</span>
              <pre class="text-xs mt-1">{{ JSON.stringify(event.data, null, 2) }}</pre>
            </div>
          </div>
        </div>
      </div>
    </div>
  </ErrorBoundary>
</template>