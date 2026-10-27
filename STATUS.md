# Laporan status

- Pemasangan: `npm` tiada dalam shell; `pnpm install` berjaya memasang 114 pakej selepas kebergantungan dibenarkan oleh runtime.
- Ujian: `pnpm test` lulus, 3 ujian.
- Build: `pnpm run build` lulus dengan TypeScript dan Vite.
- Semakan Supabase langsung: tidak dijalankan kerana tiada URL/kunci projek atau pangkalan data disediakan.
- Authorization, multi-student dan reconnect: struktur RLS/RPC ada dalam migration tetapi belum boleh disahkan terhadap Supabase hidup.
- Duplicate submit: RPC mengandungi idempotensi untuk submission berulang; belum diuji terhadap Postgres hidup.
- Pengayaan AR: belum dibuat; tiada kawalan AR yang tidak berfungsi dipaparkan. Visual 2D digunakan.
- Mod demo: berfungsi dengan localStorage, kuiz, markah, maklum balas, kemajuan, dashboard setempat dan CSV.
