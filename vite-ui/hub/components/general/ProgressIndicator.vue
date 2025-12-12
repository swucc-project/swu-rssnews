<script setup lang="ts">
const props = withDefaults(defineProps<{
  value: number; // ค่าความคืบหน้า (0-100)
  max?: number;
  label?: string;
  color?: 'primary' | 'secondary' | 'accent' | 'success' | 'warning' | 'info' | 'error';
}>(), {
  max: 100,
  label: '',
  color: 'primary',
});

const progressClass = `progress progress-${props.color}`;
</script>

<template>
  <div class="w-full p-2 font-sarabun">
    <label v-if="label || value > 0" class="label">
      <span class="label-text">{{ label }}</span>
      <span class="label-text-alt">{{ value }}%</span>
    </label>
    <!-- ใช้ progress bar จาก DaisyUI -->
    <progress 
      :class="progressClass" 
      :value="value" 
      :max="max"
    ></progress>
  </div>
</template>