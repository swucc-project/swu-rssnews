<script setup lang="ts">
import { computed } from 'vue';
import { Link } from '@inertiajs/vue3';
import { useQuery } from '@vue/apollo-composable';
import { graphql } from '~apollo/generated';
import CoreLayout from '@components/layouts/CoreLayout.vue';
import LoadingSpinner from '@components/general/LoadingSpinner.vue';
import FailureNotice from '@components/general/FailureNotice.vue';
import EmptyState from '@components/general/EmptyState.vue';
import { formatThaiDate, timeAgo } from '~tools/date-packages';

const props = defineProps({
    message: String,
    categoryId: [String, Number],
});

// ✅ แก้ไข: ลบ categoryId argument ออกจาก query
const GET_ITEMS_QUERY = graphql(`
    query GetRssFeedItems {
        rssItems {
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

const { result, loading, error } = useQuery(
    GET_ITEMS_QUERY,
    {},
    {
        fetchPolicy: 'cache-and-network'
    }
);

// ✅ กรอง items ตาม categoryId ใน frontend
const rssItems = computed(() => {
    const items = result.value?.rssItems ?? [];
    if (props.categoryId) {
        const categoryIdNum = parseInt(String(props.categoryId));
        return items.filter(item => item.category?.categoryID === categoryIdNum);
    }
    return items;
});
</script>

<template>
    <CoreLayout>
        <div class="container mx-auto p-6 font-sarabun">
            <h1 v-if="message" class="text-3xl font-bold mb-6 text-gray-800">{{ message }}</h1>
            
            <LoadingSpinner 
                v-if="loading && !rssItems.length" 
                text="กำลังโหลดรายการข่าวสาร..." 
                size="lg"
            />
            
            <FailureNotice 
                v-else-if="error" 
                :message="`เกิดข้อผิดพลาด: ${error.message}`"
                type="error"
            />
            
            <EmptyState 
                v-else-if="rssItems.length === 0" 
                message="ไม่พบรายการข่าวสาร" 
            />
            
            <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                <div 
                    v-for="item in rssItems" 
                    :key="item.itemID" 
                    class="card bg-base-100 shadow-xl hover:shadow-2xl transition-shadow duration-300"
                >
                    <div class="card-body">
                        <h2 class="card-title text-xl font-semibold">{{ item.title }}</h2>
                        <div class="text-gray-600 line-clamp-3 mt-2" v-html="item.description"></div>
                        
                        <div class="mt-4 space-y-1 text-xs text-gray-500">
                            <p v-if="item.category" class="badge badge-outline">
                                {{ item.category.categoryName }}
                            </p>
                            <p>เผยแพร่: {{ formatThaiDate(item.publishedDate) }}</p>
                            <p class="text-gray-400">{{ timeAgo(item.publishedDate) }}</p>
                            <p v-if="item.author">
                                ผู้เขียน: {{ item.author.firstName }} {{ item.author.lastName }}
                            </p>
                        </div>
                        
                        <div class="card-actions justify-end items-center mt-4">
                            <Link 
                                :href="`/rss/update/${item.itemID}`" 
                                class="btn btn-sm btn-warning"
                            >
                                แก้ไข
                            </Link>
                            <a 
                                :href="item.link" 
                                target="_blank" 
                                rel="noopener noreferrer" 
                                class="btn btn-sm btn-primary"
                            >
                                อ่านเพิ่มเติม
                            </a>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </CoreLayout>
</template>

<style scoped>
.line-clamp-3 {
    display: -webkit-box;
    -webkit-line-clamp: 3;
    -webkit-box-orient: vertical;
    overflow: hidden;
}
</style>