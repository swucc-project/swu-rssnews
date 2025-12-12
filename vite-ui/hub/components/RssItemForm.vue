<script setup lang="ts">
import { reactive, ref, watch, onMounted, computed } from 'vue';
import { useQuery } from '@vue/apollo-composable';
import gql from 'graphql-tag';
import { CATEGORY_FIELDS, AUTHOR_FIELDS } from '@generated/fragments';
import VueDatePicker from '@vuepic/vue-datepicker';
import '@vuepic/vue-datepicker/dist/main.css';
import { customDayjs } from '~tools/date-packages';

interface FormData {
    title: string;
    link: string;
    description: string;
    publishedDate: Date | string;
    categoryId: number | null;
    authorId: string | null;
}

const props = defineProps<{
    initialData?: Partial<FormData>;
    isSubmitting?: boolean;
    loading?: boolean;
}>();

const emit = defineEmits<{
    (e: 'submit', data: FormData): void;
}>();

const form = reactive<FormData>({
    title: '',
    link: '',
    description: '',
    publishedDate: new Date(),
    categoryId: null,
    authorId: null,
});

// Query สำหรับดึง Categories และ Authors
const GET_FORM_DATA_QUERY = gql`
    query GetFormData {
        categories { ...CategoryFields }
        authors { ...AuthorFields }
    }
    ${CATEGORY_FIELDS}
    ${AUTHOR_FIELDS}
`;

const { result: formDataResult, loading: loadingFormData } = useQuery(GET_FORM_DATA_QUERY);

const categories = computed(() => formDataResult.value?.categories ?? []);
const authors = computed(() => formDataResult.value?.authors ?? []);

// Watch for prop changes
watch(() => props.initialData, (newData) => {
    if (newData) {
        Object.assign(form, {
            title: newData.title || '',
            link: newData.link || '',
            description: newData.description || '',
            publishedDate: newData.publishedDate ? new Date(newData.publishedDate) : new Date(),
            categoryId: newData.categoryId || null,
            authorId: newData.authorId || null,
        });
    }
}, { deep: true, immediate: true });

function handleSubmit() {
    emit('submit', { ...form });
}

// Thai locale for datepicker
const thaiLocale = {
    months: [
        'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
        'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม'
    ],
    monthsShort: [
        'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
        'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
    ],
    weekdays: ['อาทิตย์', 'จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์'],
    weekdaysShort: ['อา.', 'จ.', 'อ.', 'พ.', 'พฤ.', 'ศ.', 'ส.'],
    weekdaysMin: ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส'],
};

// Format date for display
const formatDate = (date: Date) => {
    return customDayjs(date).format('D MMMM BBBB');
};
</script>

<template>
    <form @submit.prevent="handleSubmit" class="font-sarabun">
        <div v-if="props.loading || loadingFormData" class="text-center py-8">
            <LoadingSpinner text="กำลังโหลดข้อมูลฟอร์ม..." />
        </div>
        
        <table v-else class="table-outline w-full">
            <tbody>
                <!-- Title -->
                <tr>
                    <th class="required-label w-1/3">หัวข้อข่าว</th>
                    <td>
                        <input 
                            type="text" 
                            v-model="form.title" 
                            placeholder="กรอกหัวข้อข่าวที่นี่" 
                            required 
                        />
                    </td>
                </tr>
                
                <!-- Link -->
                <tr>
                    <th class="required-label">URL Address</th>
                    <td>
                        <input 
                            type="url" 
                            v-model="form.link" 
                            placeholder="https://example.com/news" 
                            required 
                        />
                    </td>
                </tr>
                
                <!-- Description -->
                <tr>
                    <th class="required-label">รายละเอียดของข่าว</th>
                    <td>
                        <textarea 
                            v-model="form.description" 
                            placeholder="กรอกรายละเอียดข่าวที่นี่" 
                            required
                        ></textarea>
                    </td>
                </tr>
                
                <!-- Published Date with VueDatePicker -->
                <tr>
                    <th class="required-label">วันที่เผยแพร่</th>
                    <td>
                        <VueDatePicker 
                            v-model="form.publishedDate"
                            :locale="thaiLocale"
                            :format="formatDate"
                            :enable-time-picker="false"
                            auto-apply
                            :clearable="false"
                            :teleport="true"
                        />
                    </td>
                </tr>
                
                <!-- Category -->
                <tr>
                    <th class="required-label">ประเภทข่าว</th>
                    <td>
                        <select v-model="form.categoryId" required>
                            <option :value="null" disabled>เลือกประเภทข่าว</option>
                            <option 
                                v-for="cat in categories" 
                                :key="cat.categoryID" 
                                :value="cat.categoryID"
                            >
                                {{ cat.categoryName }}
                            </option>
                        </select>
                    </td>
                </tr>
                
                <!-- Author -->
                <tr>
                    <th class="required-label">ผู้เผยแพร่</th>
                    <td>
                        <select v-model="form.authorId" required>
                            <option :value="null" disabled>เลือกผู้เผยแพร่</option>
                            <option 
                                v-for="auth in authors" 
                                :key="auth.buasriID" 
                                :value="auth.buasriID"
                            >
                                {{ auth.firstName }} {{ auth.lastName }}
                            </option>
                        </select>
                    </td>
                </tr>
                
                <!-- Submit Button -->
                <tr>
                    <td colspan="2" class="form-actions">
                        <button 
                            type="submit" 
                            class="btn-submit" 
                            :disabled="isSubmitting"
                        >
                            <span v-if="isSubmitting" class="inline-block mr-2">
                                <svg class="animate-spin h-5 w-5 inline" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                                    <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                                    <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                                </svg>
                            </span>
                            <slot name="submit-text">บันทึก</slot>
                        </button>
                    </td>
                </tr>
            </tbody>
        </table>
    </form>
</template>

<style scoped>
/* Component-specific overrides */
</style>