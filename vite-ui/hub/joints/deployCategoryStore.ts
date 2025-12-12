import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import { useGetAllCategoriesQuery, type CategoryObject } from '@generated/graphql';

export const useCategoryStore = defineStore('categories', () => {
    // === State ===
    const categories = ref<CategoryObject[]>([]);
    const loading = ref(false);
    const error = ref<Error | null>(null);
    const hasFetched = ref(false); // เพิ่ม state เพื่อเช็คว่าเคยดึงข้อมูลมาแล้วหรือยัง

    // === Getters ===
    const categoryCount = computed(() => categories.value.length);
    const categoryOptions = computed(() =>
        categories.value.map(cat => ({
            label: cat.categoryName,
            value: cat.categoryID,
        }))
    );
    // Getter สำหรับหา category เดียวตาม ID
    const getCategoryById = computed(() => {
        return (id: string | number) => categories.value.find(c => c.categoryID == id);
    });

    // === Actions ===
    // แก้ไข Action ให้ดึงข้อมูลแค่ครั้งเดียว
    function fetchCategories() {
        // ถ้ากำลังโหลดอยู่ หรือเคยดึงมาแล้ว ไม่ต้องทำอะไร
        if (loading.value || hasFetched.value) {
            return;
        }

        loading.value = true;
        error.value = null;

        // เรียกใช้ useQuery นอก onResult/onError
        const { onResult, onError } = useGetAllCategoriesQuery();

        onError(err => {
            console.error("Failed to fetch categories:", err);
            error.value = err;
            loading.value = false;
        });

        onResult(queryResult => {
            if (queryResult.data) {
                categories.value = (queryResult.data.categories as CategoryObject[]) || [];
                hasFetched.value = true; // ตั้งค่าว่าดึงข้อมูลสำเร็จแล้ว
            }
            // หยุด loading แม้ว่า data จะเป็น null
            loading.value = false;
        });
    }

    // Action สำหรับ invalidate cache และดึงข้อมูลใหม่ (เช่น หลังเพิ่ม/ลบ Category)
    function refetchCategories() {
        hasFetched.value = false;
        fetchCategories();
    }

    return {
        // State
        categories,
        loading,
        error,
        // Getters
        categoryCount,
        categoryOptions,
        getCategoryById,
        // Actions
        fetchCategories,
        refetchCategories,
    };
});