<script setup>
defineProps({
    text: {
        type: String,
        default: 'กำลังโหลด...'
    },
    size: {
        type: String,
        default: 'md',
        validator: (value) => ['sm', 'md', 'lg'].includes(value)
    }
});

const sizeClasses = {
    sm: 'loading-sm',
    md: 'loading-md',
    lg: 'loading-lg'
};
</script>

<template>
    <div class="flex flex-col items-center justify-center py-8 font-sarabun">
        <span class="loading loading-spinner loading-primary" :class="sizeClasses[size]"></span>
        <p class="mt-4 text-lg text-gray-600">{{ text }}</p>
    </div>
</template>