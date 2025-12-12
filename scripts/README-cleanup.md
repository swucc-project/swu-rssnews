# 🧹 Docker Cleanup Guide

## 📖 คู่มือการใช้งาน

### โหมดการทำความสะอาด

| Mode | ลบอะไร | ปลอดภัย | ใช้เมื่อ |
|------|--------|---------|----------|
| `Quick` | Stopped containers, dangling images | ✅ | ใช้ประจำทุกวัน |
| `Safe` | ข้างบน + unused images, networks | ✅ | สัปดาห์ละครั้ง |
| `Full -KeepData` | ข้างบน + build cache | ⚠️ | เดือนละครั้ง |
| `Full` | ทุกอย่างรวม volumes | ❌ | ก่อน redeploy |
| `Reset` | ทุกอย่าง (เหมือนใหม่) | ❌ | ติดปัญหาร้ายแรง |

### ตัวอย่างการใช้งาน

```powershell
# ประจำวัน
.\scripts\docker-cleanup.ps1 -Mode Quick

# ประจำสัปดาห์
.\scripts\docker-cleanup.ps1 -Mode Safe

# ก่อน rebuild
.\scripts\docker-cleanup.ps1 -Mode Full -KeepData

# ทดสอบก่อนลบจริง
.\scripts\docker-cleanup.ps1 -Mode Deep -DryRun

# ดู disk usage
.\scripts\docker-cleanup.ps1 -Mode Normal -ShowStats