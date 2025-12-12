<script setup>
import { ref, computed } from 'vue';
import { useQuery } from '@vue/apollo-composable';
import gql from 'graphql-tag';
import { RSS_ITEM_FIELDS } from '~apollo/generated/fragments';
import { formatThaiDate, timeAgo } from '~tools/date-packages';

const props = defineProps({
    message: String,
    categoryId: [String, Number],
});

const GET_ITEMS_QUERY = gql`
    query GetRssItems($categoryId: Int) {
        rssItems(categoryId: $categoryId) {
            ...RssItemFields
        }
    }
    ${RSS_ITEM_FIELDS}
`;

const { result, loading, error, refetch } = useQuery(
    GET_ITEMS_QUERY,
    () => ({
        categoryId: props.categoryId ? parseInt(props.categoryId) : null
    }),
    {
        fetchPolicy: 'cache-and-network'
    }
);

const rssItems = computed(() => result.value?.rssItems ?? []);
</script>

<template>
    <div class="container mx-auto p-6 font-sarabun">
        <h1 v-if="message" class="text-3xl font-bold mb-6 text-gray-800">{{ message }}</h1>
        
        <LoadingSpinner v-if="loading && !rssItems.length" text="กำลังโหลดรายการข่าวสาร..." />
        
        <FailureNotice v-else-if="error" :message="`เกิดข้อผิดพลาด: ${error.message}`" />
        
        <EmptyState v-else-if="rssItems.length === 0" message="ไม่พบรายการข่าวสาร" />
        
        <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            <div 
                v-for="item in rssItems" 
                :key="item.itemID" 
                class="card bg-base-100 shadow-xl hover:shadow-2xl transition-shadow duration-300"
            >
                <div class="card-body">
                    <h2 class="card-title text-xl font-semibold">{{ item.title }}</h2>
                    <p class="text-gray-600 line-clamp-3 mt-2" v-html="item.description"></p>
                    
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
</template>