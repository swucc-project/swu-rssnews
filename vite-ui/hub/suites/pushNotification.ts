import { emitter } from '~tools/emitter';

type NotificationType = 'success' | 'info' | 'warning' | 'error';

interface NotificationPayload {
    message: string;
    type: NotificationType;
}

function show(message: string, type: NotificationType) {
    emitter.emit('new-notification', { message, type });
}

/**
 * Composable สำหรับแสดง notifications
 * 
 * @example
 * ```vue
 * <script setup>
 * import { pushNotification } from '@hub/suites/pushNotification';
 * 
 * const notify = pushNotification();
 * 
 * notify.success('บันทึกสำเร็จ');
 * notify.error('เกิดข้อผิดพลาด');
 * </script>
 * ```
 */
export function pushNotification() {
    return {
        /**
         * แสดง notification แบบ success (สีเขียว)
         */
        success: (message: string) => show(message, 'success'),

        /**
         * แสดง notification แบบ info (สีฟ้า)
         */
        info: (message: string) => show(message, 'info'),

        /**
         * แสดง notification แบบ warning (สีเหลือง)
         */
        warning: (message: string) => show(message, 'warning'),

        /**
         * แสดง notification แบบ error (สีแดง)
         */
        error: (message: string) => show(message, 'error'),

        /**
         * แสดง notification แบบกำหนดเอง
         */
        show: (payload: NotificationPayload) => {
            emitter.emit('new-notification', payload);
        }
    };
}

// ✅ Export default for backward compatibility
export default pushNotification;