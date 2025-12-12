<template>
    <div class="signin-canvas">
        <!-- Logo Section -->
        <div class="signin-logo">
            <img 
                :src="swuLogo" 
                alt="ตราสัญลักษณ์มหาวิทยาลัยศรีนครินทรวิโรฒ" 
            />
        </div>

        <!-- Title Section -->
        <h1 class="signin-title">
            SWU News Authentication
        </h1>

        <!-- Sign In Form -->
        <form @submit.prevent="manipulateLogin" class="signin-form">
            <!-- Error Alert -->
            <div v-if="authStore.error" class="alert alert-error">
                <div class="flex items-start gap-3">
                    <svg 
                        xmlns="http://www.w3.org/2000/svg" 
                        class="flex-shrink-0" 
                        fill="none" 
                        viewBox="0 0 24 24"
                    >
                        <path 
                            stroke-linecap="round" 
                            stroke-linejoin="round" 
                            stroke-width="2" 
                            d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z" 
                        />
                    </svg>
                    <span>{{ authStore.error }}</span>
                </div>
            </div>

            <!-- Buasri ID Input -->
            <div class="form-group">
                <label for="buasriId">รหัสบัวศรี (Buasri ID)</label>
                <input 
                    type="text" 
                    id="buasriId" 
                    v-model="buasriId" 
                    placeholder="กรอกรหัสบัวศรีของคุณ"
                    required
                    autocomplete="username"
                    :disabled="authStore.loading"
                />
            </div>

            <!-- Password Input -->
            <div class="form-group">
                <label for="password">รหัสผ่าน (Password)</label>
                <input 
                    type="password" 
                    id="password" 
                    v-model="password" 
                    placeholder="กรอกรหัสผ่านของคุณ"
                    required
                    autocomplete="current-password"
                    :disabled="authStore.loading"
                />
            </div>

            <!-- Submit Button -->
            <button 
                type="submit" 
                class="btn-signin"
                :class="{ 'loading': authStore.loading }" 
                :disabled="authStore.loading"
            >
                {{ authStore.loading ? 'กำลังเข้าสู่ระบบ...' : 'Sign In' }}
            </button>
        </form>
    </div>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import { useAuthStore } from '@hub/auth';
import swuLogo from '~images/swu_logo.png';

const props = defineProps<{
    returnUrl?: string;
}>();

const buasriId = ref('');
const password = ref('');

const authStore = useAuthStore();

const manipulateLogin = async () => {
    await authStore.login(
        buasriId.value, 
        password.value, 
        props.returnUrl || null
    );
};
</script>