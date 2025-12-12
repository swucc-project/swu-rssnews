// 1. Import dayjs และ plugins ที่จำเป็น
import dayjs, { type Dayjs } from 'dayjs';

// ---- Plugins ----
// Plugin สำหรับจัดการ Timezone (สำคัญมากสำหรับเว็บแอป)
import utc from 'dayjs/plugin/utc';
import timezone from 'dayjs/plugin/timezone';

// Plugin สำหรับแสดงผลเป็นปี พ.ศ.
import buddhistEra from 'dayjs/plugin/buddhistEra';

// Plugin สำหรับแสดงผลแบบ "relative time" (เช่น "5 นาทีที่แล้ว")
import relativeTime from 'dayjs/plugin/relativeTime';

// Plugin สำหรับรองรับภาษาไทย (ชื่อเดือน, ชื่อวัน)
import 'dayjs/locale/th';

// 2. สั่งให้ dayjs ใช้งาน plugins ที่เรา import เข้ามา
dayjs.extend(utc);
dayjs.extend(timezone);
dayjs.extend(buddhistEra);
dayjs.extend(relativeTime);

// 3. ตั้งค่าภาษาเริ่มต้นเป็นภาษาไทย
dayjs.locale('th');

// 4. (แนะนำ) ตั้งค่า Timezone เริ่มต้นของโปรเจกต์
// เพื่อให้แน่ใจว่าการแปลงเวลาจะสอดคล้องกันทั่วทั้งแอป
// ควรใช้ Timezone ที่ตรงกับกลุ่มผู้ใช้งานหลัก เช่น 'Asia/Bangkok'
dayjs.tz.setDefault('Asia/Bangkok');


// -----------------------------------------------------------------
// 5. สร้างและ Export ฟังก์ชันสำเร็จรูปสำหรับนำไปใช้
// -----------------------------------------------------------------

/**
 * Type ที่ยอมรับได้สำหรับฟังก์ชันต่างๆ
 * สามารถรับค่าได้ทั้ง Date object, string, number (timestamp), หรือ dayjs object
 */
type DateInput = Date | string | number | Dayjs;

/**
 * แปลงวันที่เป็นรูปแบบภาษาไทยเต็ม (เช่น "15 พฤษภาคม 2567")
 * @param date - วันที่ที่ต้องการแปลง
 * @returns string ของวันที่ในรูปแบบภาษาไทย
 */
export function formatThaiDate(date: DateInput): string {
    if (!date) return '';
    // 'BBBB' คือ format code สำหรับปีพุทธศักราช (พ.ศ.)
    return dayjs(date).format('D MMMM BBBB');
}

/**
 * แปลงวันที่เป็นรูปแบบภาษาไทยแบบย่อ (เช่น "15 พ.ค. 67")
 * @param date - วันที่ที่ต้องการแปลง
 * @returns string ของวันที่ในรูปแบบย่อ
 */
export function formatThaiDateShort(date: DateInput): string {
    if (!date) return '';
    // 'MMM' คือชื่อเดือนย่อ, 'BB' คือปี พ.ศ. แบบย่อ
    return dayjs(date).format('D MMM BB');
}

/**
 * แปลงวันที่และเวลาเป็นรูปแบบภาษาไทย (เช่น "15 พฤษภาคม 2567, 14:30 น.")
 * @param date - วันที่และเวลาที่ต้องการแปลง
 * @returns string ของวันที่และเวลาในรูปแบบภาษาไทย
 */
export function formatThaiDateTime(date: DateInput): string {
    if (!date) return '';
    return dayjs(date).format('D MMMM BBBB, HH:mm น.');
}

/**
 * แปลงวันที่เป็นรูปแบบ "relative time" (เช่น "เมื่อสักครู่", "5 นาทีที่แล้ว", "2 ชั่วโมงที่แล้ว")
 * @param date - วันที่ที่ต้องการเปรียบเทียบกับเวลาปัจจุบัน
 * @returns string ของเวลาที่สัมพันธ์กับปัจจุบัน
 */
export function timeAgo(date: DateInput): string {
    if (!date) return '';
    return dayjs(date).fromNow();
}

/**
 * Export ตัวแปร dayjs ที่ตั้งค่าเรียบร้อยแล้ว เผื่อต้องการใช้งานฟังก์ชันอื่นๆ ที่ซับซ้อน
 * โดยเมื่อเรียกใช้ จะได้ instance ที่เป็นภาษาไทยและรองรับปี พ.ศ. ทันที
 * ตัวอย่าง: customDayjs(someDate).isBefore(anotherDate)
 */
export const customDayjs = dayjs;