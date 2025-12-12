<script setup>
import { computed } from 'vue';
import { Link, usePage } from '@inertiajs/vue3';
import { useQuery } from '@vue/apollo-composable';
import gql from 'graphql-tag';
import { CATEGORY_FIELDS } from '@generated/fragments';
import LoadingSpinner from '@components/general/LoadingSpinner.vue';
import FailureNotice from '@components/general/FailureNotice.vue';

const page = usePage();

const GET_CATEGORIES_QUERY = gql`
    query GetCategories {
        categories {
            ...CategoryFields
        }
    }
    ${CATEGORY_FIELDS}
`;

const { result, loading, error } = useQuery(GET_CATEGORIES_QUERY);
const categories = computed(() => result.value?.categories ?? []);
const currentCategoryId = computed(() => page.props.categoryId);

const isActiveCategory = (categoryId) => {
    if (currentCategoryId.value == null && categoryId === null) return true;
    return currentCategoryId.value == categoryId;
};
</script>

<template>
    <aside class="menu-bar vertical p-4 rounded-lg shadow-md bg-white">
        <h3 class="text-2xl font-bold mb-4 pb-3 border-b-2 font-sarabun-new">
            <svg 
                xmlns="http://www.w3.org/2000/svg" 
                class="h-6 w-6 inline-block mr-2" 
                fill="none" 
                viewBox="0 0 24 24" 
                stroke="currentColor"
            >
                <path 
                    stroke-linecap="round" 
                    stroke-linejoin="round" 
                    stroke-width="2" 
                    d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z" 
                />
            </svg>
            ประเภทข่าว
        </h3>
        
        <!-- Loading State -->
        <div v-if="loading" class="py-4">
            <LoadingSpinner text="โหลดหมวดหมู่..." size="sm" />
        </div>
        
        <!-- Error State -->
        <FailureNotice 
            v-else-if="error" 
            :message="`ไม่สามารถโหลดหมวดหมู่: ${error.message}`"
            type="warning"
        />
        
        <!-- Categories List -->
        <ul v-else class="menu space-y-1">
            <!-- All News Link -->
            <li>
                <Link 
                    href="/rss" 
                    class="flex items-center gap-2 px-4 py-3 rounded-md transition-all duration-200 font-sarabun-new text-lg"
                    :class="isActiveCategory(null) 
                        ? 'active font-bold bg-red-50 text-red-700' 
                        : 'hover:bg-red-50 hover:text-red-600'"
                >
                    <svg 
                        xmlns="http://www.w3.org/2000/svg" 
                        class="h-5 w-5" 
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
                    <span>ข่าวทั้งหมด</span>
                </Link>
            </li>
            
            <li class="menu-title">
                <span class="text-xs uppercase text-gray-500">หมวดหมู่</span>
            </li>
            
            <!-- Category Links -->
            <li v-for="category in categories" :key="category.categoryID">
                <Link 
                    :href="`/rss/view/${category.categoryID}`" 
                    class="flex items-center gap-2 px-4 py-3 rounded-md transition-all duration-200 font-sarabun-new text-lg"
                    :class="isActiveCategory(category.categoryID) 
                        ? 'active font-bold bg-red-50 text-red-700 border-l-4 border-red-700' 
                        : 'hover:bg-red-50 hover:text-red-600'"
                >
                    <svg 
                        xmlns="http://www.w3.org/2000/svg" 
                        class="h-5 w-5" 
                        fill="none" 
                        viewBox="0 0 24 24" 
                        stroke="currentColor"
                    >
                        <path 
                            stroke-linecap="round" 
                            stroke-linejoin="round" 
                            stroke-width="2" 
                            d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z" 
                        />
                    </svg>
                    <span>{{ category.categoryName }}</span>
                </Link>
            </li>
        </ul>
        
        <!-- Category Count -->
        <div v-if="categories.length > 0" class="mt-6 pt-4 border-t border-gray-200">
            <p class="text-sm text-gray-500 font-sarabun-new text-center">
                <svg 
                    xmlns="http://www.w3.org/2000/svg" 
                    class="h-4 w-4 inline-block mr-1" 
                    fill="none" 
                    viewBox="0 0 24 24" 
                    stroke="currentColor"
                >
                    <path 
                        stroke-linecap="round" 
                        stroke-linejoin="round" 
                        stroke-width="2" 
                        d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z" 
                    />
                </svg>
                ทั้งหมด {{ categories.length }} หมวดหมู่
            </p>
        </div>
    </aside>
</template>

<style scoped>
.menu-title {
    padding: 0.5rem 1rem;
}
</style>