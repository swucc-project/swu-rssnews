import { Api } from '~api/generated/api';
import axios, { type AxiosInstance, type AxiosRequestConfig } from 'axios';

// สร้าง axios instance พร้อม config
const axiosInstance: AxiosInstance = axios.create({
    baseURL: import.meta.env.VITE_API_URL || 'http://localhost:5000',
    withCredentials: true, // สำคัญ! สำหรับ cookie authentication
    headers: {
        'Content-Type': 'application/json',
        'Accept-Language': 'th-TH',
    },
});

// Request Interceptor
axiosInstance.interceptors.request.use(
    (config) => {
        // เพิ่ม auth token ถ้ามี
        const token = localStorage.getItem('authToken');
        if (token) {
            config.headers.Authorization = `Bearer ${token}`;
        }
        return config;
    },
    (error) => {
        return Promise.reject(error);
    }
);

// Response Interceptor
axiosInstance.interceptors.response.use(
    (response) => response,
    (error) => {
        if (error.response?.status === 401) {
            // Redirect to login
            window.location.href = '/rss/signin';
        }
        return Promise.reject(error);
    }
);

// สร้าง API Client
export const apiClient = new Api({
    baseURL: import.meta.env.VITE_API_URL || 'http://localhost:5000',
    baseApiParams: {
        credentials: 'include',
        headers: {
            'Content-Type': 'application/json',
            'Accept-Language': 'th-TH',
        },
    },
});

// Export types
export type { Api } from './generated/api';