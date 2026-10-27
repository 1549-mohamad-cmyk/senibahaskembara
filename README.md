# SeniBahasa Adventure 3.0

Aplikasi kuiz Bahasa Melayu Tahun 4 yang menyokong SK 4.1 dan SP 4.1.1. UI utama berbahasa Melayu dan responsif untuk telefon serta desktop.

## Mula

```sh
npm install
npm run dev
```

Mod demo aktif secara lalai. Nama, kemajuan dan percubaan disimpan di localStorage pelayar semasa. Dashboard guru menunjukkan rekod demo setempat, dan eksport CSV memuat turun rekod tersebut. Audio ialah bunyi maklum balas ringkas menggunakan Web Audio API.

## Supabase (asas backend disediakan)

1. Salin `.env.example` kepada `.env.local` dan isi URL serta anon key projek.
2. Jalankan `supabase/migrations/202610270001_senibahasa.sql` melalui Supabase CLI atau SQL Editor.
3. Jalankan `supabase/seed/seed.sql` untuk seed kuiz.

Skema menyediakan profil, peranan guru/murid, kuiz, soalan, sesi, submission, RPC `start_quiz`, `submit_answer`, dan `teacher_dashboard`. Polisi RLS memisahkan sesi murid; soalan tiada polisi SELECT supaya kunci jawapan tidak boleh dibaca oleh klien, dan penilaian berlaku dalam RPC bertransaksi. Guru perlu diberikan `profiles.role='teacher'` secara pentadbir sahaja. Presence masa nyata dan UI login/penyegerakan belum disambungkan kepada aplikasi; medan VITE Supabase ketika ini disediakan sebagai asas konfigurasi sahaja. Aplikasi berjalan dalam mod demo sehingga integrasi klien tersebut dibuat.

## Kurikulum

Bank soalan merujuk DSKP KSSR Bahasa Melayu SK Tahun 4, bahagian Seni Bahasa: SK 4.1 “Mengaplikasikan unsur keindahan dan kesantunan bahasa dalam bahan sastera”; SP 4.1.1 “Bercerita dan mengujarkan dialog yang mengandungi peribahasa.” Semakan teks dokumen: [salinan DSKP Tahun 4](https://asiemodel.net/wp-content/uploads/2022/08/DSKP-BM-TAHUN-4-SK_LATEST.pdf). Sumber ini ialah hos bahan pendidikan, bukan domain KPM; sahkan salinan terkini dengan repositori BPK/KPM sebelum penggunaan rasmi.

## Status ciri

- **Siap:** 10 soalan dengan taburan 3 sukar, 4 sederhana, 3 mudah; kemajuan, markah, maklum balas, dashboard guru tempatan, CSV, reka bentuk responsif dan kesan audio.
- **Simulasi/demo:** identiti murid, penyimpanan sesi dan paparan dashboard menggunakan localStorage; lencana MOD DEMO dipaparkan.
- **Asas backend disediakan, belum disambungkan:** Supabase Auth client, presence, pemulihan sesi pelayan dan RPC dari UI.
- **Belum dilaksanakan:** AR kamera/ruang sebenar. Tiada butang AR palsu; ilustrasi 2D ialah fallback visual.

## Pengesahan

Lihat `npm test` dan `npm run build`. Laporan status sebenar dimasukkan dalam penyerahan Codex selepas arahan dijalankan.
