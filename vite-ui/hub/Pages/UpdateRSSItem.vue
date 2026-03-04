<script setup lang="ts">
import { ref, computed } from 'vue';
import { useQuery, useMutation } from '@vue/apollo-composable';
import { graphql } from '~apollo/generated';
import { router } from '@inertiajs/vue3';
import CoreLayout from '@components/layouts/CoreLayout.vue';
import RssItemForm from '@components/RssItemForm.vue';
import LoadingSpinner from '@components/general/LoadingSpinner.vue';
import SuccessMessage from '@components/general/SuccessMessage.vue';
import FailureNotice from '@components/general/FailureNotice.vue';

const props = defineProps<{
    itemID: string;
}>();

const successMessage = ref('');
const errorMessage = ref('');

// ✅ เปลี่ยนชื่อ operation
const GET_ITEM_QUERY = graphql(`
    query GetRssItemForUpdate($id: String!) {
        rssItem(id: $id) {
            itemID
            title
            link
            description
            publishedDate
            category {
                categoryID
            }
            author {
                buasriID
            }
        }
    }
`);

const UPDATE_ITEM_MUTATION = graphql(`
    mutation UpdateRssItem($id: String!, $input: UpdateItemInput!) {
        updateItem(id: $id, input: $input) {
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

const { result, loading: loadingItem, error: itemError } = useQuery(GET_ITEM_QUERY, { id: props.itemID });

const initialFormData = computed(() => {
    if (!result.value?.rssItem) return null;
    const item = result.value.rssItem;
    return {
        title: item.title,
        link: item.link,
        description: item.description,
        publishedDate: item.publishedDate ? new Date(item.publishedDate) : new Date(),
        categoryId: item.category?.categoryID || null,
        authorId: item.author?.buasriID || null,
    };
});

const { mutate: updateItem, loading: isSubmitting, onDone, onError } = useMutation(UPDATE_ITEM_MUTATION);

onDone(() => {
    successMessage.value = 'แก้ไขข่าวสำเร็จ! กำลังนำทางกลับ...';
    errorMessage.value = '';
    setTimeout(() => router.visit('/rss', { replace: true }), 2000);
});

onError(error => {
    errorMessage.value = `เกิดข้อผิดพลาด: ${error.message}`;
    successMessage.value = '';
});

async function handleSubmit(formData: any) {
    successMessage.value = '';
    errorMessage.value = '';
    
    await updateItem({
        id: props.itemID,
        item: {
            ...formData,
            publishedDate: new Date(formData.publishedDate).toISOString(),
            categoryId: formData.categoryId ? parseInt(formData.categoryId) : null,
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
                        แก้ไขข่าวและกิจกรรม
                    </h1>
                    <p class="text-center text-gray-600 mt-2 font-sarabun text-lg">
                        แก้ไขข้อมูลในฟอร์มด้านล่าง
                    </p>
                </div>
                
                <!-- Form Container -->
                <div class="bg-white rounded-b-lg shadow-md p-6">
                    <LoadingSpinner 
                        v-if="loadingItem" 
                        text="กำลังโหลดข้อมูล..." 
                        size="lg"
                    />
                    
                    <FailureNotice 
                        v-else-if="itemError" 
                        :message="`เกิดข้อผิดพลาด: ${itemError.message}`"
                        type="error"
                    />
                    
                    <RssItemForm 
                        v-else-if="initialFormData"
                        :initial-data="initialFormData"
                        :is-submitting="isSubmitting"
                        :loading="loadingItem"
                        @submit="handleSubmit"
                    >
                        <template #submit-text>
                            <svg class="w-5 h-5 inline-block mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                            </svg>
                            บันทึกการแก้ไข
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