<script setup lang="ts">
import { reactive, watch, computed } from 'vue';
import { useQuery } from '@vue/apollo-composable';
import { graphql } from '~apollo/generated'; 
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

// ✅ เปลี่ยนชื่อ operation เป็น GetFormDataForRssForm
const GET_FORM_DATA_QUERY = graphql(`
    query GetFormDataForRssForm {
        categories {
            categoryID
            categoryName
        }
        authors {
            buasriID
            firstName
            lastName
        }
    }
`);

const { result: formDataResult, loading: loadingFormData } = useQuery(GET_FORM_DATA_QUERY);

const categories = computed(() => formDataResult.value?.categories ?? []);
const authors = computed(() => formDataResult.value?.authors ?? []);

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

const formatDate = (date: Date) => {
    return customDayjs(date).format('D MMMM BBBB');
};
</script>

<template>
    <form @submit.prevent="handleSubmit" class="space-y-6">
        <!-- Title -->
        <div class="form-control">
            <label class="label">
                <span class="label-text text-lg font-semibold">ชื่อข่าว *</span>
            </label>
            <input 
                v-model="form.title" 
                type="text" 
                placeholder="กรอกชื่อข่าว"
                class="input input-bordered w-full text-lg"
                required
                :disabled="props.isSubmitting || props.loading"
            />
        </div>

        <!-- Link -->
        <div class="form-control">
            <label class="label">
                <span class="label-text text-lg font-semibold">ลิงก์ข่าว *</span>
            </label>
            <input 
                v-model="form.link" 
                type="url" 
                placeholder="https://example.com/news"
                class="input input-bordered w-full text-lg"
                required
                :disabled="props.isSubmitting || props.loading"
            />
        </div>

        <!-- Description -->
        <div class="form-control">
            <label class="label">
                <span class="label-text text-lg font-semibold">รายละเอียด *</span>
            </label>
            <textarea 
                v-model="form.description" 
                placeholder="กรอกรายละเอียดข่าว"
                class="textarea textarea-bordered w-full h-32 text-lg"
                required
                :disabled="props.isSubmitting || props.loading"
            ></textarea>
        </div>

        <!-- Published Date -->
        <div class="form-control">
            <label class="label">
                <span class="label-text text-lg font-semibold">วันที่เผยแพร่ *</span>
            </label>
            <VueDatePicker
                v-model="form.publishedDate"
                :format="formatDate"
                :locale="thaiLocale"
                :enable-time-picker="false"
                :disabled="props.isSubmitting || props.loading"
                auto-apply
                class="w-full"
            />
        </div>

        <!-- Category -->
        <div class="form-control">
            <label class="label">
                <span class="label-text text-lg font-semibold">หมวดหมู่</span>
            </label>
            <select 
                v-model="form.categoryId" 
                class="select select-bordered w-full text-lg"
                :disabled="loadingFormData || props.isSubmitting || props.loading"
            >
                <option :value="null">-- เลือกหมวดหมู่ --</option>
                <option 
                    v-for="category in categories" 
                    :key="category.categoryID" 
                    :value="category.categoryID"
                >
                    {{ category.categoryName }}
                </option>
            </select>
        </div>

        <!-- Author -->
        <div class="form-control">
            <label class="label">
                <span class="label-text text-lg font-semibold">ผู้เขียน</span>
            </label>
            <select 
                v-model="form.authorId" 
                class="select select-bordered w-full text-lg"
                :disabled="loadingFormData || props.isSubmitting || props.loading"
            >
                <option :value="null">-- เลือกผู้เขียน --</option>
                <option 
                    v-for="author in authors" 
                    :key="author.buasriID" 
                    :value="author.buasriID"
                >
                    {{ author.firstName }} {{ author.lastName }}
                </option>
            </select>
        </div>

        <!-- Submit Button -->
        <div class="form-control mt-8">
            <button 
                type="submit" 
                class="btn btn-primary btn-lg w-full text-lg"
                :disabled="props.isSubmitting || props.loading || loadingFormData"
                :class="{ 'loading': props.isSubmitting }"
            >
                <slot name="submit-text">
                    {{ props.isSubmitting ? 'กำลังบันทึก...' : 'บันทึก' }}
                </slot>
            </button>
        </div>
    </form>
</template>

<style scoped>
.form-control {
    margin-bottom: 1.5rem;
}

.label-text {
    color: #374151;
    font-weight: 600;
}

/* DatePicker Custom Styles */
:deep(.dp__input) {
    height: 3rem;
    font-size: 1.125rem;
    border: 1px solid #e5e7eb;
    border-radius: 0.5rem;
}

:deep(.dp__input:focus) {
    border-color: #3b82f6;
    outline: none;
    box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
}
</style>