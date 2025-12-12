<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { useQuery } from '@vue/apollo-composable';
import { Link } from '@inertiajs/vue3';
import gql from 'graphql-tag';
import { RSS_ITEM_FIELDS } from '~apollo/generated/fragments';
import { formatThaiDate } from '~tools/date-packages';

const props = defineProps<{
    categoryId?: string | number;
}>();

const selectedCategory = ref(props.categoryId ? parseInt(String(props.categoryId)) : null);
const expandedItems = ref<Set<string>>(new Set());

const GET_INDEX_DATA_QUERY = gql`
    query GetIndexData($categoryId: Int) {
        rssItems(categoryId: $categoryId) {
            ...RssItemFields
        }
        categories {
            categoryID
            categoryName
        }
    }
    ${RSS_ITEM_FIELDS}
`;

const { result, loading, error, refetch } = useQuery(
    GET_INDEX_DATA_QUERY,
    () => ({ categoryId: selectedCategory.value }),
    { fetchPolicy: 'cache-and-network' }
);

const rssItems = computed(() => result.value?.rssItems ?? []);
const categories = computed(() => result.value?.categories ?? []);

// Toggle accordion item
const toggleItem = (itemId: string) => {
    if (expandedItems.value.has(itemId)) {
        expandedItems.value.delete(itemId);
    } else {
        expandedItems.value.add(itemId);
    }
};

const isExpanded = (itemId: string) => expandedItems.value.has(itemId);

watch(selectedCategory, () => {
    refetch({ categoryId: selectedCategory.value });
    expandedItems.value.clear(); // ปิด accordion ทั้งหมดเมื่อเปลี่ยน category
});
</script>

<template>
    <div class="news-archive">
        <!-- Header Section -->
        <div class="flex flex-col md:flex-row justify-between items-start md:items-center mb-6 gap-4">
            <h1 class="text-4xl font-bold">
                รายการข่าวและกิจกรรม
            </h1>
            <Link href="/rss/add" class="btn btn-primary">
                <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
                </svg>
                เพิ่มข่าวใหม่
            </Link>
        </div>

        <!-- Category Filter -->
        <div class="category-filter">
            <div class="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
                <div class="form-control w-full md:w-auto md:flex-1">
                    <label class="label">
                        <span class="label-text text-lg">กรองตามหมวดหมู่:</span>
                    </label>
                    <select 
                        v-model="selectedCategory" 
                        @change="refetch" 
                        class="select select-bordered w-full text-lg"
                    >
                        <option :value="null">ประเภทข่าวทั้งหมด</option>
                        <option 
                            v-for="category in categories" 
                            :key="category.categoryID" 
                            :value="category.categoryID"
                        >
                            {{ category.categoryName }}
                        </option>
                    </select>
                </div>
                
                <button 
                    @click="refetch()" 
                    class="btn btn-info mt-8 md:mt-0" 
                    :disabled="loading"
                >
                    <svg 
                        class="w-5 h-5 mr-2" 
                        :class="{ 'animate-spin': loading }"
                        fill="none" 
                        stroke="currentColor" 
                        viewBox="0 0 24 24"
                    >
                        <path 
                            stroke-linecap="round" 
                            stroke-linejoin="round" 
                            stroke-width="2" 
                            d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" 
                        />
                    </svg>
                    {{ loading ? 'กำลังโหลด...' : 'รีเฟรช' }}
                </button>
            </div>
        </div>

        <!-- Loading State -->
        <LoadingSpinner 
            v-if="loading && !rssItems.length" 
            text="กำลังโหลดข่าวสาร..." 
            class="loading-state"
        />

        <!-- Error State -->
        <FailureNotice 
            v-else-if="error" 
            :message="`เกิดข้อผิดพลาด: ${error.message}`" 
        />

        <!-- Empty State -->
        <div v-else-if="rssItems.length === 0" class="empty-state">
            <svg 
                xmlns="http://www.w3.org/2000/svg" 
                fill="none" 
                viewBox="0 0 24 24" 
                stroke="currentColor"
            >
                <path 
                    stroke-linecap="round" 
                    stroke-linejoin="round" 
                    stroke-width="2" 
                    d="M19 20H5a2 2 0 01-2-2V6a2 2 0 012-2h10a2 2 0 012 2v1m2 13a2 2 0 01-2-2V7m2 13a2 2 0 002-2V9a2 2 0 00-2-2h-2m-4-3H9M7 16h6M7 8h6v4H7V8z" 
                />
            </svg>
            <p class="text-xl font-semibold">ไม่พบข่าวและกิจกรรมในขณะนี้</p>
        </div>

        <!-- News Items with Accordion -->
        <div v-else class="news-accordion space-y-3">
            <details 
                v-for="item in rssItems"
                :key="item.itemID"
                class="collapse collapse-arrow bg-base-100 border border-base-300 rounded-box"
            >
                <summary class="collapse-title text-xl font-medium">
                    <div class="flex justify-between items-start gap-4">
                        <h3 class="text-xl font-bold flex-1">{{ item.title }}</h3>
                        <span v-if="item.category" class="badge badge-outline badge-lg whitespace-nowrap">
                            {{ item.category.categoryName }}
                        </span>
                    </div>
                </summary>

                <div class="collapse-content">
                    <!-- เดิมๆ ทั้งหมดใน brief-explanation -->
                    <div class="brief-explanation">
                        <!-- Description -->
                        <div v-if="item.description" class="mb-4">
                            <h4 class="text-lg font-bold mb-2">รายละเอียด:</h4>
                            <div v-html="item.description" class="prose max-w-none"></div>
                        </div>
                        <!-- Link -->
                        <div class="detail-item">
                            <span class="detail-label">ลิงก์:</span>
                            <a :href="item.link" target="_blank" rel="noopener noreferrer" class="break-all">{{ item.link }}</a>
                        </div>
                        <!-- Published Date -->
                        <div class="detail-item">
                            <span class="detail-label">วันที่เผยแพร่:</span>
                            <span>{{ formatThaiDate(item.publishedDate) }}</span>
                        </div>
                        <!-- Author -->
                        <div v-if="item.author" class="detail-item">
                            <span class="detail-label">ผู้เผยแพร่:</span>
                            <span>{{ item.author.firstName }} {{ item.author.lastName }}</span>
                        </div>
                        <!-- Action Buttons -->
                        <div class="flex gap-2 mt-6 pt-4 border-t border-green-300">
                            <Link :href="`/rss/update/${item.itemID}`" class="btn btn-sm btn-warning">
                            ✏️ แก้ไข
                            </Link>
                            <Link :href="`/rss/delete/${item.itemID}`" class="btn btn-sm btn-error">
                            🗑️ ลบ
                            </Link>
                            <a :href="item.link" target="_blank" rel="noopener noreferrer" class="btn btn-sm btn-primary ml-auto">
                            🔗 เปิดลิงก์
                            </a>
                        </div>
                    </div>
                </div>
            </details>
        </div>

        <!-- Summary -->
        <div 
            v-if="rssItems.length > 0" 
            class="mt-6 pt-4 border-t border-gray-300 text-center text-lg"
        >
            <p>
                แสดงข่าวทั้งหมด 
                <span class="font-bold">{{ rssItems.length }}</span> 
                รายการ
                <span v-if="selectedCategory">
                    ในหมวด 
                    <span class="font-bold">
                        {{ categories.find(c => c.categoryID === selectedCategory)?.categoryName }}
                    </span>
                </span>
            </p>
        </div>
    </div>
</template>

<style scoped>
/* Additional component-specific styles */
.collapse-arrow {
    transition: all 0.3s ease;
}

.collapse-title {
    cursor: pointer;
    user-select: none;
}

.prose :deep(p) {
    margin-bottom: 0.75rem;
}

.prose :deep(a) {
    color: rgb(0, 0, 200);
    text-decoration: underline;
}

.prose :deep(a:hover) {
    color: rgb(200, 32, 32);
}
</style>