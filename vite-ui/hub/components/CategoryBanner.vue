<script setup>
defineProps({
    category: {
        type: Object,
        // ไม่บังคับต้องมี เพราะหน้า "ข่าวทั้งหมด" จะไม่มีข้อมูล category
        required: false,
        default: null,
    }
});
</script>

<template>
    <!-- แสดง Banner ต่อเมื่อมีข้อมูล category ถูกส่งเข้ามาเท่านั้น -->
    <div v-if="category" class="bg-blue-50 border-l-4 border-blue-500 text-blue-800 p-4 rounded-md mb-6 font-sarabun" role="alert">
        <h2 class="font-bold text-xl">{{ category.categoryName }}</h2>
        <p v-if="category.description" class="mt-1">
            {{ category.description }}
        </p>
    </div>
</template>