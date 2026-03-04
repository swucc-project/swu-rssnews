<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { useQuery } from '@vue/apollo-composable';
import { Link } from '@inertiajs/vue3';
import { graphql } from '~apollo/generated';
import CoreLayout from '@components/layouts/CoreLayout.vue';
import LoadingSpinner from '@components/general/LoadingSpinner.vue';
import FailureNotice from '@components/general/FailureNotice.vue';
import EmptyState from '@components/general/EmptyState.vue';
import { formatThaiDate } from '~tools/date-packages';

const props = defineProps<{
    categoryId?: string | number;
}>();

const selectedCategory = ref(props.categoryId ? parseInt(String(props.categoryId)) : null);

// ✅ แก้ไข: ลบ categoryId argument ออกจาก query เพราะ backend ไม่รองรับ
const GET_ITEM_QUERY = graphql(`
    query GetRssItems {
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
        categories {
            categoryID
            categoryName
        }
    }
`);

const { result, loading, error, refetch } = useQuery(
    GET_ITEM_QUERY,
    {},
    { fetchPolicy: 'cache-and-network' }
);

// ✅ กรอง items ตาม categoryId ใน frontend แทน
const rssItems = computed(() => {
    const items = result.value?.rssItems ?? [];
    if (selectedCategory.value) {
        return items.filter(item => item.category?.categoryID === selectedCategory.value);
    }
    return items;
});

const categories = computed(() => result.value?.categories ?? []);

watch(selectedCategory, () => {
    // ไม่ต้อง refetch เพราะเรากรองใน frontend
});
</script>

<template>
    <CoreLayout>
        <div class="news-archive">
            <!-- Header Section -->
            <div class="flex flex-col md:flex-row justify-between items-start md:items-center mb-6 gap-4">
                <h1 class="text-4xl font-bold font-sarabun">
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
                size="lg"
            />

            <!-- Error State -->
            <FailureNotice 
                v-else-if="error" 
                :message="`เกิดข้อผิดพลาด: ${error.message}`" 
                type="error"
            />

            <!-- Empty State -->
            <EmptyState 
                v-else-if="rssItems.length === 0"
                message="ไม่พบข่าวและกิจกรรมในขณะนี้"
            />

            <!-- News Items with Accordion -->
            <div v-else class="news-accordion space-y-3">
                <details 
                    v-for="item in rssItems"
                    :key="item.itemID"
                    class="collapse collapse-arrow bg-base-100 border border-base-300 rounded-box"
                >
                    <summary class="collapse-title text-xl font-medium">
                        <div class="flex justify-between items-start gap-4">
                            <h3 class="text-xl font-bold flex-1 font-sarabun">{{ item.title }}</h3>
                            <span v-if="item.category" class="badge badge-outline badge-lg whitespace-nowrap">
                                {{ item.category.categoryName }}
                            </span>
                        </div>
                    </summary>

                    <div class="collapse-content">
                        <div class="brief-explanation">
                            <!-- Description -->
                            <div v-if="item.description" class="mb-4">
                                <h4 class="text-lg font-bold mb-2 font-sarabun">รายละเอียด:</h4>
                                <div v-html="item.description" class="prose max-w-none"></div>
                            </div>
                            <!-- Link -->
                            <div class="detail-item">
                                <span class="detail-label">ลิงก์:</span>
                                <a :href="item.link" target="_blank" rel="noopener noreferrer" class="break-all">
                                    {{ item.link }}
                                </a>
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
                class="mt-6 pt-4 border-t border-gray-300 text-center text-lg font-sarabun"
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
    </CoreLayout>
</template>

<style scoped>
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