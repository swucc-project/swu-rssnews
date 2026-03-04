import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import {
    useGetAllItemsQuery,
    useGetRssItemQuery,
    useCreateItemMutation,
    useUpdateItemMutation,
    useDeleteItemMutation,
    type ItemObject,
} from '@generated/graphql';
import { pushNotification } from '@suites/pushNotification';

export const useRssItemStore = defineStore('rssItems', () => {
    // === State ===
    const items = ref<ItemObject[]>([]);
    const currentItem = ref<ItemObject | null>(null);
    const loadingList = ref(false);
    const loadingItem = ref(false);
    const error = ref<Error | null>(null);

    const notification = pushNotification(); // ใช้งาน plugin

    // === Actions ===

    // ดึงรายการข่าวทั้งหมด
    function fetchAllItems(categoryId?: string) {
        loadingList.value = true;
        const { onResult, onError } = useGetAllItemsQuery(
            computed(() => ({ categoryId }))
        );

        onError(err => {
            error.value = err;
            loadingList.value = false;
            notification.error('ไม่สามารถดึงข้อมูลข่าวได้');
        });

        onResult(result => {
            if (result.data) {
                items.value = (result.data.items as ItemObject[]) || [];
            }
            loadingList.value = false;
        });
    }

    // ดึงข่าวชิ้นเดียว
    function fetchItemById(id: string) {
        loadingItem.value = true;
        const { onResult, onError } = useGetRssItemQuery({ itemID: id });

        onError(err => {
            error.value = err;
            loadingItem.value = false;
            notification.error('ไม่พบข้อมูลข่าวที่ต้องการ');
        });

        onResult(result => {
            if (result.data) {
                currentItem.value = result.data.getRssItem as ItemObject;
            }
            loadingItem.value = false;
        });
    }

    // สร้างข่าวใหม่
    async function createItem(input: any) {
        const { mutate, loading, error: mutationError, onDone } = useCreateItemMutation();

        mutate({ input });

        onDone(result => {
            notification.success('สร้างข่าวสำเร็จ!');
            // อาจจะ redirect หรือ refetch list
        });

        if (mutationError.value) {
            notification.error(mutationError.value.message);
        }

        return { loading, error: mutationError };
    }

    // ... สามารถสร้าง action updateItem และ deleteItem ในลักษณะเดียวกัน ...

    return {
        items,
        currentItem,
        loadingList,
        loadingItem,
        error,
        fetchAllItems,
        fetchItemById,
        createItem,
    };
});