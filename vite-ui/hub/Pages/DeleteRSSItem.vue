<script setup>
import { useMutation, useQuery } from '@vue/apollo-composable';
import gql from 'graphql-tag';
import { ref, watch } from 'vue';
import { router } from '@inertiajs/vue3';
import '~css/theme.css';
import { RSS_ITEM_FIELDS } from '~apollo/generated/fragments';

const props = defineProps({
    initialId: { type: String, required: true }
});

const GET_RSS_ITEM_QUERY = gql`
    query GetRSSItemById($id: ID!) {
        rssItem(id: $id) {
            id
            title
        }
    }
`;

const DELETE_RSS_ITEM_MUTATION = gql`
    mutation DeleteRssItem($id: ID!) {
        # ตรวจสอบชื่อ mutation ใน schema ของคุณ อาจจะเป็น deleteRssItem หรือ deleteRSSItem
        deleteRssItem(id: $id) {
            id 
        }
    }
`;

const itemIdToDelete = ref(props.initialId || '');
const itemTitle = ref('');
const successMessage = ref('');
const errorMessage = ref('');
const isSubmitting = ref(false);

const { result, loading, error } = useQuery(GET_RSS_ITEM_QUERY, { id: itemIdToDelete.value });

watch(result, (newResult) => {
    if (newResult && newResult.rssItem) {
        itemTitle.value = newResult.rssItem.title;
    }
}, { immediate: true });

const { mutate: deleteRssItem, onDone, onError } = useMutation(DELETE_RSS_ITEM_MUTATION);

onDone(() => {
    isSubmitting.value = false;
    successMessage.value = `ลบข่าวและกิจกรรม "${itemTitle.value}" สำเร็จแล้ว! กำลังกลับไปหน้าหลัก...`;
    setTimeout(() => {
        router.visit('/rss'); // Redirect after a short delay
    }, 2000);
});

onError((err) => {
    isSubmitting.value = false;
    errorMessage.value = `เกิดข้อผิดพลาดในการลบ: ${err.message}`;
    console.error('Error deleting RSS item:', err);
});

const handleSubmit = async () => {
    const confirmed = confirm(`คุณต้องการลบข่าวและกิจกรรม "${itemTitle.value}" จริงหรือ?`);
    if (confirmed) {
        isSubmitting.value = true;
        successMessage.value = '';
        errorMessage.value = '';
        await deleteRssItem({ id: itemIdToDelete.value });
    }
};
</script>
<template>
    <div class="container mx-auto p-6">
        <div class="p-6 bg-white rounded-lg shadow-md max-w-xl mx-auto mt-10">
            <h1 class="text-2xl font-bold mb-4 font-sarabun text-red-600">ยืนยันการลบข่าวและกิจกรรม</h1>
            <div v-if="loading" class="text-center py-4">
                <p>กำลังโหลดข้อมูล...</p>
            </div>
            <div v-else-if="error" class="alert alert-error font-sarabun">
                <p>เกิดข้อผิดพลาดในการโหลดข้อมูล: {{ error.message }}</p>
            </div>
            <div v-else-if="itemTitle">
                <p class="text-gray-700 mb-4">
                    คุณกำลังจะลบรายการต่อไปนี้อย่างถาวร:
                </p>
                <div class="bg-red-50 p-4 rounded border-l-4 border-red-500 mb-6">
                    <p class="text-gray-700">
                        <span class="font-semibold">ID:</span>
                        <span class="font-mono text-blue-500">{{ itemIdToDelete }}</span>
                    </p>
                    <p class="text-gray-700 mt-2">
                        <span class="font-semibold">ชื่อข่าว:</span>
                        <span class="font-bold text-red-700">{{ itemTitle }}</span>
                    </p>
                </div>
                 <div class="flex justify-between items-center">
                    <button @click="router.visit('/rss')" class="btn btn-ghost font-sarabun">ยกเลิก</button>
                    <button 
                        @click="handleSubmit" 
                        class="btn bg-red-600 hover:bg-red-700 text-white font-bold py-2 px-4 rounded-lg font-sarabun" 
                        :disabled="isSubmitting"
                    >
                        {{ isSubmitting ? 'กำลังลบ...' : 'ยืนยันการลบ' }}
                    </button>
                </div>
            </div>
             <div v-else class="text-center py-4 font-sarabun">
                ไม่พบข้อมูลรายการที่ต้องการลบ
            </div>
            
            <div v-if="successMessage" class="alert alert-success mt-6 font-sarabun text-center">
                {{ successMessage }}
            </div>
            <div v-if="errorMessage" class="alert alert-error mt-6 font-sarabun text-center">
                {{ errorMessage }}
            </div>
        </div>
    </div>  
</template>