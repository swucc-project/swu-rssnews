import mitt from 'mitt';

// กำหนด Type ของ Event เพื่อให้ได้รับ intellisense ที่ดี
type Events = {
    'new-notification': {
        message: string;
        type: 'success' | 'info' | 'warning' | 'error';
    }
};

export const emitter = mitt<Events>();