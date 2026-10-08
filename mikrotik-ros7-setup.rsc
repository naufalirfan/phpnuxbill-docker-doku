# ==============================================================================
# Script Konfigurasi MikroTik RouterOS v7 untuk PHPNuxBill & DOKU QRIS
# ==============================================================================

/log info message="=== Memulai Konfigurasi MikroTik RouterOS v7 untuk Billing & DOKU ==="

# 1. Aktifkan Service API (Port 8728)
/ip service set api disabled=no port=8728

# 2. Buat Group Izin User Billing
/user group add name=billing policy=read,write,api,policy,test comment="PHPNuxBill API Group"

# 3. Buat User API untuk PHPNuxBill (Ganti Password Sesuai Kebutuhan)
/user add name=phpnuxbill group=billing password="NuxBillMikrotikPass2026!" comment="User API PHPNuxBill"

# 4. Walled Garden Hotspot DOKU (Agar pelanggan belum login bisa akses checkout DOKU & bayar QRIS)
/ip hotspot walled-garden
add dst-host=*doku.com action=allow comment="DOKU Gateway"
add dst-host=*jokul.doku.com action=allow comment="DOKU Jokul Checkout"
add dst-host=*api.doku.com action=allow comment="DOKU API Production"
add dst-host=*api-sandbox.doku.com action=allow comment="DOKU API Sandbox"
add dst-host=*doku.id action=allow comment="DOKU Shortlink"
add dst-host=*cloudflared.net action=allow comment="Cloudflare Tunnel"
add dst-host=*trycloudflare.com action=allow comment="Cloudflare Quick Tunnel"

/log info message="=== Konfigurasi MikroTik RouterOS v7 Berhasil Diterapkan ==="
