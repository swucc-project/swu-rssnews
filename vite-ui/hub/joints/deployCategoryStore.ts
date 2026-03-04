import { defineStore } from 'pinia';
import { ref, computed } from 'vue';

interface Category {
    categoryID: string | number;
    categoryName: string;
}

export const useCategoryStore = defineStore('categories', () => {
    // State
    const categories = ref<Category[]>([]);
    const loading = ref(false);
    const error = ref<Error | null>(null);
    const hasFetched = ref(false);

    // Getters
    const categoryCount = computed(() => categories.value.length);

    const categoryOptions = computed(() =>
        categories.value.map(cat => ({
            label: cat.categoryName,
            value: cat.categoryID,
        }))
    );

    const getCategoryById = computed(() => {
        return (id: string | number) =>
            categories.value.find(c => c.categoryID == id);
    });

    // Actions
    async function fetchCategories() {
        if (loading.value || hasFetched.value) {
            return;
        }

        loading.value = true;
        error.value = null;

        try {
            // ✅ Lazy import inside async function
            const { useGetAllCategoriesQuery } = await import('@generated/graphql');

            const { onResult, onError } = useGetAllCategoriesQuery();

            onError((err: Error) => {
                console.error("Failed to fetch categories:", err);
                error.value = err;
                loading.value = false;
            });

            onResult((queryResult: any) => {
                if (queryResult.data) {
                    categories.value = (queryResult.data.categories as Category[]) || [];
                    hasFetched.value = true;
                }
                loading.value = false;
            });
        } catch (err) {
            console.warn("⚠️ GraphQL not available, using fallback:", err);
            // Fallback to empty categories
            categories.value = [];
            hasFetched.value = true;
            loading.value = false;
            error.value = err instanceof Error ? err : new Error('GraphQL unavailable');
        }
    }

    function refetchCategories() {
        hasFetched.value = false;
        fetchCategories();
    }

    return {
        categories,
        loading,
        error,
        categoryCount,
        categoryOptions,
        getCategoryById,
        fetchCategories,
        refetchCategories,
    };
});