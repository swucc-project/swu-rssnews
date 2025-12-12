import { emitter } from '~tools/emitter';

type NotificationType = 'success' | 'info' | 'warning' | 'error';

function show(message: string, type: NotificationType) {
    emitter.emit('new-notification', { message, type });
}

// สร้างเป็น Composable function เพื่อให้เรียกใช้ใน store หรือ component ได้ง่าย
export function useNotification() {
    return {
        success: (message: string) => show(message, 'success'),
        info: (message: string) => show(message, 'info'),
        warning: (message: string) => show(message, 'warning'),
        error: (message: string) => show(message, 'error'),
    };
}