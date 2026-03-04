// 1. Import dayjs และ plugins ที่จำเป็น
import dayjs, { type Dayjs } from 'dayjs';

// ---- Plugins ----
import utc from 'dayjs/plugin/utc';
import timezone from 'dayjs/plugin/timezone';
import buddhistEra from 'dayjs/plugin/buddhistEra';
import relativeTime from 'dayjs/plugin/relativeTime';
import 'dayjs/locale/th';

// 2. สั่งให้ dayjs ใช้งาน plugins
dayjs.extend(utc);
dayjs.extend(timezone);
dayjs.extend(buddhistEra);
dayjs.extend(relativeTime);

// 3. ตั้งค่าภาษาเริ่มต้นเป็นภาษาไทย
dayjs.locale('th');

// 4. ตั้งค่า Timezone เริ่มต้น
dayjs.tz.setDefault('Asia/Bangkok');

// -----------------------------------------------------------------
// 5. Helper Functions
// -----------------------------------------------------------------

type DateInput = Date | string | number | Dayjs;

function isValidDateInput(date: unknown): date is DateInput {
    return date !== null && date !== undefined && date !== '';
}

/**
 * แปลงวันที่เป็นรูปแบบภาษาไทยเต็ม (เช่น "15 พฤษภาคม 2567")
 */
export function formatThaiDate(date: DateInput): string {
    if (!isValidDateInput(date)) return '';
    return dayjs(date).tz('Asia/Bangkok').format('D MMMM BBBB');
}

/**
 * แปลงวันที่เป็นรูปแบบภาษาไทยแบบย่อ (เช่น "15 พ.ค. 67")
 */
export function formatThaiDateShort(date: DateInput): string {
    if (!isValidDateInput(date)) return '';
    return dayjs(date).tz('Asia/Bangkok').format('D MMM BB');
}

/**
 * แปลงวันที่และเวลาเป็นรูปแบบภาษาไทย (เช่น "15 พฤษภาคม 2567, 14:30 น.")
 */
export function formatThaiDateTime(date: DateInput): string {
    if (!isValidDateInput(date)) return '';
    return dayjs(date).tz('Asia/Bangkok').format('D MMMM BBBB, HH:mm น.');
}

/**
 * แปลงวันที่เป็นรูปแบบ "relative time" (เช่น "5 นาทีที่แล้ว")
 */
export function timeAgo(date: DateInput): string {
    if (!isValidDateInput(date)) return '';
    // fromNow จะคำนวณจากเวลาปัจจุบันของเครื่องผู้ใช้ ซึ่งถูกต้องแล้วสำหรับ relative time
    return dayjs(date).fromNow();
}

/**
 * แปลงวันที่สำหรับใช้กับ input type="datetime-local" (yyyy-MM-ddTHH:mm)
 * มักใช้ตอนทำ Form แก้ไขข้อมูล
 */
export function formatForInput(date: DateInput): string {
    if (!isValidDateInput(date)) return '';
    return dayjs(date).tz('Asia/Bangkok').format('YYYY-MM-DDTHH:mm');
}

export const customDayjs = dayjs;