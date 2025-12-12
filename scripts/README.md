# 🛠️ Scripts สำหรับการจัดการระบบ

## 📜 รายการสคริปต์ทั้งหมด

### 🚀 การเริ่มต้นและหยุดระบบ

#### 1. `quick-start.ps1` ⭐
เริ่มโปรเจคแบบครบวงจร (แนะนำสำหรับผู้เริ่มต้น)

**การใช้งาน:**
```powershell
# Development (ค่าเริ่มต้น)
.\scripts\quick-start.ps1

# Production
.\scripts\quick-start.ps1 -Environment Production

# ข้าม Firewall setup
.\scripts\quick-start.ps1 -SkipFirewall

# ข้าม WSL2 port forwarding
.\scripts\quick-start.ps1 -SkipPortForward