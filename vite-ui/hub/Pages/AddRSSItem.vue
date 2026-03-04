<script setup lang="ts">
import { ref } from 'vue';
import { useMutation } from '@vue/apollo-composable';
import { graphql } from '~apollo/generated'; // ✅ ใช้ graphql function
import { router } from '@inertiajs/vue3';
import RssItemForm from '@components/RssItemForm.vue';
import CoreLayout from '@components/layouts/CoreLayout.vue';
import SuccessMessage from '@components/general/SuccessMessage.vue';
import FailureNotice from '@components/general/FailureNotice.vue';

const successMessage = ref('');
const errorMessage = ref('');

// ✅ ใช้ graphql function แทน gql
const ADD_ITEM_MUTATION = graphql(`
    mutation AddRSSItem($input: AddItemInput!) {
        addItem(input: $input) {
            itemID
            title
            link
            description
            publishedDate
            category {
                categoryID
                categoryName
            }
            author {
                buasriID
                firstName
                lastName
            }
        }
    }
`);

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
    <CoreLayout>
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
                    <SuccessMessage 
                        v-if="successMessage"
                        title="สำเร็จ!"
                        :message="successMessage"
                    />
                    
                    <!-- Error Message -->
                    <FailureNotice 
                        v-if="errorMessage"
                        :message="errorMessage"
                        type="error"
                    />
                </div>
            </div>
        </div>
    </CoreLayout> 
</template>