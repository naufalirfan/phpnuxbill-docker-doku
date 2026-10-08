# 🌐 PHPNuxBill Dockerized + DOKU Payment Gateway (QRIS) & MikroTik RouterOS v7

[![Docker](https://img.shields.io/badge/Docker-24.0+-blue.svg)](https://www.docker.com/)
[![PHP](https://img.shields.io/badge/PHP-8.2-777BB4.svg)](https://www.php.net/)
[![MariaDB](https://img.shields.io/badge/MariaDB-10.11-003545.svg)](https://mariadb.org/)
[![MikroTik](https://img.shields.io/badge/MikroTik-RouterOS%20v7-black.svg)](https://mikrotik.com/)
[![DOKU](https://img.shields.io/badge/DOKU-Jokul%20Checkout-red.svg)](https://doku.com/)
[![Cloudflare Tunnel](https://img.shields.io/badge/Cloudflare-Tunnel-orange.svg)](https://cloudflare.com/)

Modifikasi dan modernisasi **PHPNuxBill** (Aplikasi Billing Hotspot & PPPoE MikroTik) siap pakai berbasis **Docker**, dilengkapi dengan modul integrasi **DOKU Payment Gateway (QRIS Dynamic, Virtual Account, E-Wallet)**, skrip konfigurasi **MikroTik RouterOS v7**, serta dukungan **Cloudflare Tunnel** untuk akses publik tanpa memerlukan IP Publik Statis.

---

## ⚡ Perbedaan & Peningkatan dari Versi Original

Repositori ini merupakan modifikasi dan peningkatan dari repositori upstream resmi [hotspotbilling/phpnuxbill](https://github.com/hotspotbilling/phpnuxbill):

| Fitur / Komponen | Versi Original (`hotspotbilling/phpnuxbill`) | Versi Modifikasi Ini |
| :--- | :--- | :--- |
| **Lingkungan Deployment** | Setup manual web server (Apache/Nginx + PHP FPM di OS host) | **Full Docker & Docker Compose** (PHP 8.2 Apache + MariaDB 10.11) sekali jalan (`docker compose up -d`) |
| **Payment Gateway** | Tripay, Midtrans, Xendit bawaan standard | **DOKU Jokul Checkout** (QRIS Dynamic otomatis terbit, Virtual Account, notifikasi Webhook callback instan) |
| **Kompatibilitas PHP** | Dioptimalkan untuk PHP 7.4 - 8.0 (beberapa notice deprecated di 8.2+) | **PHP 8.2 Native Support** dengan ekstensi Apache mod_rewrite, mysqli, gd, curl, bcmath, sockets |
| **Halaman Statis** | Sering terjadi 404 / template tidak ditemukan pada instalasi fresh | **Fixed Static Pages** (Template Smarty & Markdown untuk Announcement, Payment Information, Voucher, dll.) |
| **Dukungan MikroTik** | Script generic RouterOS v6 | **RouterOS v7 Ready** (API Service, IP Hotspot Walled Garden terintegrasi untuk DOKU & Cloudflare) |
| **Akses Publik** | Membutuhkan Port Forwarding / IP Publik ISP | **Cloudflare Tunnel Ready** (Terkoneksi via `cloudflared`, akses HTTPS aman melalui subdomain publik) |

---

## 🏗️ Topologi & Arsitektur

```mermaid
graph TD
    Client[HP / Pelanggan Hotspot] -->|1. Scan QRIS / Pilih Paket| BillingPub[https://billing.naufalputra.my.id]
    BillingPub -->|Cloudflare Tunnel| DockerApp[Container PHPNuxBill (PHP 8.2)]
    DockerApp <-->|Query Plans & Users| DockerDB[(Container MariaDB 10.11)]
    DockerApp -->|2. Generate Invoice / QRIS| DOKU[DOKU Jokul Gateway API]
    DOKU -->|3. Webhook Callback Sukses| DockerApp
    DockerApp -->|4. RouterOS API (Port 8728)| MikroTik[MikroTik RouterOS v7]
    MikroTik -->|5. Buka Akses Internet| Client
```

---

## 📁 Struktur Repositori

```
├── Dockerfile                   # Build image PHP 8.2 + Apache + ekstensi lengkap
├── docker-compose.yml           # Orkestrasi container App + MariaDB
├── .htaccess                    # Rewrite rules Apache untuk routing PHPNuxBill
├── .env.example                 # Contoh variabel environment
├── doku.php                     # Engine modul payment gateway DOKU (Checkout & Callback)
├── doku_config.tpl              # Form UI pengaturan DOKU di dashboard Admin
├── mikrotik-ros7-setup.rsc      # Script konfigurasi RouterOS v7 (API & Walled Garden)
├── setup-intel-nuc.sh           # Script alternatif auto-install native LEMP di Debian/Ubuntu
├── pages/                       # File halaman statis yang telah diperbaiki
│   ├── Announcement.html
│   ├── Order_Voucher.html
│   ├── Payment_Info.html
│   ├── Terms_and_Conditions.html
│   ├── Voucher.html
│   └── ...
└── README.md                    # Dokumentasi lengkap
```

---

## 🚀 Panduan Instalasi Cepat

### 1. Prasyarat
- Server / Mini PC (Intel NUC / VPS) dengan Linux (Debian 12 / Ubuntu 22.04+).
- Docker & Docker Compose sudah terpasang.
- Router MikroTik RouterOS v7 terhubung ke server.

### 2. Clone Repositori & Persiapan Direktori
```bash
git clone https://github.com/naufalirfan/phpnuxbill-docker-doku.git
cd phpnuxbill-docker-doku
cp .env.example .env
```

### 3. Clone Source PHPNuxBill ke Folder `app/`
```bash
git clone https://github.com/hotspotbilling/phpnuxbill.git app
cp doku.php app/system/paymentgateway/doku.php
cp doku_config.tpl app/ui/ui/doku_config.tpl
cp -r pages/* app/pages/
cp .htaccess app/.htaccess
```

### 4. Jalankan Container
```bash
docker compose up -d --build
```
Aplikasi akan aktif di `http://<IP_SERVER>:8086`.

---

## ⚙️ Konfigurasi MikroTik RouterOS v7

Buka Terminal di Winbox MikroTik Anda, lalu jalankan script berikut (atau import dari `mikrotik-ros7-setup.rsc`):

```routeros
# 1. Aktifkan Service API MikroTik
/ip service set api disabled=no port=8728

# 2. Buat User Khusus Billing
/user group add name=billing policy=read,write,api,policy,test
/user add name=phpnuxbill group=billing password="PasswordAmanMikrotik123!"

# 3. Walled Garden untuk DOKU & Tunnel (Akses payment tanpa login hotspot)
/ip hotspot walled-garden add dst-host=*doku.com action=allow
/ip hotspot walled-garden add dst-host=*jokul.doku.com action=allow
/ip hotspot walled-garden add dst-host=*api.doku.com action=allow
/ip hotspot walled-garden add dst-host=*api-sandbox.doku.com action=allow
/ip hotspot walled-garden add dst-host=*cloudflare.com action=allow
/ip hotspot walled-garden add dst-host=*cfargotunnel.com action=allow
```

---

## 💳 Konfigurasi DOKU Payment Gateway

1. Buka dashboard admin PHPNuxBill (`/index.php?_route=admin`).
2. Masuk ke **Settings** -> **Payment Gateway** -> **DOKU**.
3. Masukkan:
   - **Client ID**: Client ID dari Dashboard DOKU Jokul.
   - **Secret Key**: Secret Key / Shared Key DOKU.
   - **Environment**: `Sandbox` (Pengujian) atau `Production` (Live).
   - **Expired Time**: `60` (dalam hitungan menit).
4. Di Dashboard DOKU Merchant, atur URL Notifikasi:
   - **Notification URL**: `https://<domain-anda>/index.php?_route=callback/doku`

---

## 🔒 Konfigurasi Cloudflare Tunnel

Agar billing dapat diakses publik dengan aman melalui domain sendiri (misal `https://billing.naufalputra.my.id`):
1. Install `cloudflared` di server.
2. Di Dashboard **Cloudflare One > Networks > Connectors > Tunnels**:
   - Pilih Tunnel Anda.
   - Buka tab **Published application routes** -> **+ Add a published application route**.
   - Subdomain: `billing`
   - Domain: `domainanda.com`
   - Type: `HTTP`
   - URL: `localhost:8086`
3. Simpan rute. Cloudflare otomatis meneruskan lalu lintas HTTPS publik ke container di port 8086.

---

## 👏 Kredit & Penghargaan

Proyek ini dibangun di atas fondasi karya hebat komunitas open-source:
- **PHPNuxBill Original**: Diciptakan oleh **[Ibnu Maksum](https://github.com/ibnumaksum)** dan dikembangkan bersama komunitas di **[hotspotbilling/phpnuxbill](https://github.com/hotspotbilling/phpnuxbill)**. Terima kasih banyak atas dedikasi dan kontribusi luar biasa untuk dunia RT/RW Net dan ISP Indonesia.
- **Modifikasi, Docker Containerization, & DOKU Gateway**: Dikembangkan oleh **[Naufal Irfansyah Saputra](https://github.com/naufalirfan)**.

---

## 📄 Lisensi
PHPNuxBill dilisensikan di bawah lisensi open source [MIT / GPL](https://github.com/hotspotbilling/phpnuxbill).
