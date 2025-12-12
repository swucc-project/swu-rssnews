<script setup lang="ts">
import { useSubscription, useMutation } from '@vue/apollo-composable';
import gql from 'graphql-tag';
import { emitter } from '~tools/emitter'; // Import event bus
import ErrorBoundary from './ErrorBoundary.vue'; // Import ErrorBoundary
import { RSS_ITEM_FIELDS } from '~apollo/generated/fragments'; // Import fragment ที่เรามี
import { ref } from 'vue';

// --- 1. GraphQL Subscription ---
// Subscription นี้จะ "ฟัง" event จาก server เมื่อมี item ใหม่ถูกเพิ่มเข้ามา
// (คุณต้อง implement resolver สำหรับ 'newItemAdded' ใน backend ของคุณ)
const NEW_ITEM_SUBSCRIPTION = gql`
  ${RSS_ITEM_FIELDS}
  subscription OnNewItemAdded {
    newItemAdded {
      ...RssItemFields
    }
  }
`;

// --- 2. ใช้งาน useSubscription ---
const { result, loading, error, onResult } = useSubscription(NEW_ITEM_SUBSCRIPTION);

// onResult เป็น hook ที่จะทำงานทุกครั้งที่ได้รับข้อมูลใหม่จาก subscription
onResult(queryResult => {
  if (queryResult.data) {
    const newItem = queryResult.data.newItemAdded;
    console.log('Received new item via WebSocket:', newItem);
    
    // ส่ง event ไปให้ SynchronousNotification แสดงผล
    emitter.emit('new-notification', {
      message: `ข่าวใหม่: ${newItem.title}`,
      type: 'info',
    });
  }
});


// --- 3. (Optional) สร้าง Mutation เพื่อ Trigger Subscription ---
// ส่วนนี้ใช้สำหรับทดสอบ เพื่อให้เราสามารถ "สร้างข่าว" จากฝั่ง Client ได้เลย
// และดูว่า Subscription ของเราทำงานถูกต้องหรือไม่
const title = ref('');
const ADD_ITEM_MUTATION = gql`
  mutation AddTestItem($title: String!) {
    createItem(input: { title: $title, link: "http://example.com", description: "Test item" }) {
      itemID
      title
    }
  }
`;
const { mutate: addItem, loading: mutationLoading, onError: onMutationError } = useMutation(ADD_ITEM_MUTATION);

const handleAddItem = async () => {
    if (!title.value) return;
    await addItem({ title: title.value });
    title.value = ''; // Clear input after submission
};

onMutationError(err => {
    emitter.emit('new-notification', {
      message: `Error adding item: ${err.message}`,
      type: 'error',
    });
});
</script>

<template>
  <ErrorBoundary>
    <div class="card bg-base-100 shadow-xl m-4 font-sarabun">
      <div class="card-body">
        <h2 class="card-title">WebSocket Subscription Test</h2>
        
        <!-- ส่วนแสดงสถานะ Subscription -->
        <div class="mt-4">
          <p>สถานะการเชื่อมต่อ WebSocket:</p>
          <div v-if="loading" class="badge badge-info">กำลังเชื่อมต่อ...</div>
          <div v-else-if="error" class="badge badge-error">เชื่อมต่อล้มเหลว: {{ error.message }}</div>
          <div v-else class="badge badge-success">เชื่อมต่อสำเร็จและกำลังรอรับข้อมูล</div>
        </div>

        <!-- ส่วนแสดงข้อมูลล่าสุดที่ได้รับ -->
        <div v-if="result" class="mt-4 p-2 bg-base-200 rounded-lg">
          <p class="font-semibold">ข้อมูลล่าสุดที่ได้รับ:</p>
          <pre class="text-xs whitespace-pre-wrap">{{ result.newItemAdded.title }}</pre>
        </div>

        <!-- ส่วนสำหรับทดสอบ (Trigger Mutation) -->
        <div class="divider">ทดสอบการส่งข้อมูล</div>
        <div class="form-control">
            <label class="label"><span class="label-text">สร้างข่าวเพื่อทดสอบ:</span></label>
            <div class="join">
                <input v-model="title" type="text" placeholder="ใส่ชื่อข่าวที่นี่" class="input input-bordered join-item w-full"/>
                <button @click="handleAddItem" class="btn btn-primary join-item" :class="{ 'loading': mutationLoading }" :disabled="mutationLoading">
                    ส่ง
                </button>
            </div>
        </div>

      </div>
    </div>
  </ErrorBoundary>
</template>