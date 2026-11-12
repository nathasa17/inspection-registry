# Exit Ticket: Praktikum Minggu ke-9

## Identitas

- Nama: Nabila Shandy Nathasa, NIM: 2313000005
- Nama: Anisa Kustiawati, NIM: 2413000006

## Pertanyaan

> Fungsi mana yang paling berbahaya jika authorization-nya salah, dampak apa yang dapat terjadi, dan test apa yang membuktikan bahwa kontrolnya bekerja?

## Jawaban

Fungsi yang paling berbahaya jika authorization-nya salah adalah `approve()`, karena fungsi ini yang mengubah status record menjadi `APPROVED`, yaitu status yang menyatakan sebuah inspeksi sah. Jika pemeriksaan `msg.sender != regulator` hilang atau keliru, vendor dapat menyetujui sendiri inspeksinya tanpa pernah diperiksa regulator, sehingga data yang tampak resmi di blockchain menjadi tidak dapat dipercaya dan invariant utama kontrak rusak. Kontrol ini dibuktikan oleh test `testNonRegulatorCannotApprove`: setelah `submit()`, test memanggil `approve()` lewat kontrak lain (`NonRegulatorCaller`) yang bukan regulator, memastikan panggilan gagal (`success == false`), lalu memastikan status record tetap `SUBMITTED`. Hasilnya lulus pada `npx hardhat test` (4 passing), sehingga terbukti bahwa aksi yang dilarang benar-benar ditolak dan tidak mengubah state. Fungsi `revoke()` memakai pemeriksaan yang sama, tetapi belum memiliki test khusus pada pengumpulan ini.
