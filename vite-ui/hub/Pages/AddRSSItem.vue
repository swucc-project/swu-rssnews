<script setup lang="ts">
import { ref } from 'vue';
import { useMutation } from '@vue/apollo-composable';
import gql from 'graphql-tag';
import { router } from '@inertiajs/vue3';
import RssItemForm from '@components/RssItemForm.vue';
import { RSS_ITEM_FIELDS } from '@generated/fragments';

const successMessage = ref('');
const errorMessage = ref('');

const ADD_ITEM_MUTATION = gql`
    mutation AddRSSItem($item: ItemInput!) {
        addItem(item: $item) { ...RssItemFields }
    }
    ${RSS_ITEM_FIELDS}
`;

const { mutate: addItem, loading, onDone, onError } = useMutation(ADD_ITEM_MUTATION);

onDone(() => {
    successMessage.value = 'เพิ่มข่าวสำเร็จ! กำลังนำทางกลับ...';
    errorMessage.value = '';
    setTimeout(() => router.visit('/rss', { replace: true }), 2000);
});

onError(error => {
    errorMessage.value = `เกิดข้อผิดพลาด: ${error.message}`;
    successMessage.value = '';
});

async function handleSubmit(formData: any) {
    errorMessage.value = '';
    successMessage.value = '';
    
    await addItem({
        item: {
            ...formData,
            publishedDate: new Date(formData.publishedDate).toISOString(),
            categoryId: parseInt(formData.categoryId), 
        }
    });
}
</script>

<template>
    <div class="container mx-auto p-4 md:p-6">
        <div class="max-w-5xl mx-auto mt-6">
            <!-- Header -->
            <div class="bg-white rounded-t-lg shadow-md p-6 border-b-4 border-pink-300">
                <h1 class="text-4xl font-bold text-center text-gray-800 font-sarabun">
                    เพิ่มข่าวและกิจกรรมใหม่
                </h1>
                <p class="text-center text-gray-600 mt-2 font-sarabun text-lg">
                    กรอกข้อมูลในฟอร์มด้านล่างเพื่อเพิ่มข่าวใหม่
                </p>
            </div>
            
            <!-- Form Container -->
            <div class="bg-white rounded-b-lg shadow-md p-6">
                <RssItemForm 
                    @submit="handleSubmit" 
                    :is-submitting="loading"
                >
                    <template #submit-text>
                        <svg class="w-5 h-5 inline-block mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
                        </svg>
                        เพิ่มข่าว
                    </template>
                </RssItemForm>
                
                <!-- Success Message -->
                <div v-if="successMessage" class="alert alert-success mt-6 font-sarabun text-lg">
                    <svg class="w-6 h-6 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                    </svg>
                    {{ successMessage }}
                </div>
                
                <!-- Error Message -->
                <div v-if="errorMessage" class="alert alert-error mt-6 font-sarabun text-lg">
                    <svg class="w-6 h-6 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                    </svg>
                    {{ errorMessage }}
                </div>
            </div>
        </div>
    </div>
</template>