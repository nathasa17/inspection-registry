# Praktikum Blockchain Minggu 10: Smart Contract Correctness & Access Control

## 1. Identitas
- **Nama:** Nabila Shandy Nathasa (2313000005)
- **Nama:** Anisa Kustiawati (2413000006)
- **URL Repo:** [https://github.com/nathasa17/inspection-registry/tree/praktikum/minggu-10]
- **Commit Baseline (V1):** a741cf18
- **Commit Final (V2):** 44102a4f

## 2. Versi Tools
- **Node.js:** v22.23.4
- **npm:** 10.9.9
- **Hardhat:** 3.21.2
- **Solidity Config:** 0.8.24
- **OpenZeppelin:** 5.4.0

## 3. Perintah Eksekusi
- Instalasi dependensi: `npm ci`
- Kompilasi: `npx hardhat compile`
- Menjalankan test: `npx hardhat test solidity`

## 4. Ringkasan Perubahan V1 ke V2
Kontrak V2 mengimplementasikan Role-Based Access Control (RBAC) menggunakan OpenZeppelin. Terdapat penambahan VENDOR_ROLE dan REGULATOR_ROLE. Constructor baru membutuhkan parameter admin dan regulator. Modifikasi fungsi menyertakan validasi role (`onlyRole`), validasi status transisi (`atStatus`), dan custom error yang lebih informatif (seperti `InvalidStatus`).

## 5. Matriks Role dan Transisi State
- **VENDOR_ROLE:** Berhak memanggil `submit()` pada state `NONE` untuk mengubah state ke `SUBMITTED`.
- **REGULATOR_ROLE:** Berhak memanggil `approve()` pada state `SUBMITTED` menjadi `APPROVED`, serta memanggil `revoke()` pada state `APPROVED` menjadi `REVOKED`.
- **DEFAULT_ADMIN_ROLE:** Mengelola otorisasi (`grantRole` dan `revokeRole`).

## 6. Tabel Hasil Test
| Test | State awal | Actor | Aksi | Expected | Actual |
|---|---|---|---|---|---|
| VendorCannotApprove | SUBMITTED | Vendor | approve(ID) | AccessControlUnauthorizedAccount | AccessControlUnauthorizedAccount |
| ApprovalEmitsExactAuditEvent | SUBMITTED | Regulator | approve(ID) | APPROVED; from=1 to=2, actor benar | Sesuai |
| testCannotApproveOwnSubmission | SUBMITTED | Vendor dgn Role Ganda | approve(ID) | Revert SelfApprovalNotAllowed | Revert SelfApprovalNotAllowed |

## 7. Bukti Field Tidak Berubah Saat Gagal
Saat memanggil fungsi revoke tanpa menyertakan `reasonHash` yang valid, transaksi di-revert (EmptyReason). Hasil snapshot membuktikan state tetap `APPROVED` dan seluruh data record tidak berubah.

## 8. Bukti Mutation Check
- **Kontrol Dihapus:** Menghapus `onlyRole(REGULATOR_ROLE)` pada fungsi `approve`.
- **Hasil Test Gagal:** Test `testVendorCannotApprove` gagal karena eksekusi berhasil dijalankan oleh Vendor.
- **Kontrol Dipulihkan:** Setelah mengembalikan modifier `onlyRole(REGULATOR_ROLE)`, seluruh test kembali pass.

## 9. Pilihan Perubahan Individual
- **Pilihan:** A - Larangan Self-Approval.
- **Alasan Desain:** Mencegah konflik kepentingan di mana satu address yang memiliki role Vendor sekaligus Regulator menyetujui laporannya sendiri.
- **Test Baru:** `testCannotApproveOwnSubmission` (Negative) dan `testOtherRegulatorCanApprove` (Positive).

## 10. Pertanyaan Analisis & Refleksi
**Analisis CEI:** Jika ada notify contract sebelum status APPROVED dan notify memanggil balik fungsi approve, status masih SUBMITTED, sehingga fungsi bisa dieksekusi berulang (reentrancy) jika kontrol lain terlewat, meskipun guard atStatus akan menggagalkan pemanggilan berikutnya.
**Keterbatasan:** AccessControl belum sepenuhnya bisa memisahkan identitas manusia yang menggunakan banyak wallet (Sybil).
**Deklarasi AI:** Saya menggunakan asisten AI untuk memandu penyalinan kode dari PDF guna mencegah typo, serta memformat template README. Verifikasi dilakukan dengan menjalankan test secara lokal di WSL.

**Refleksi (100-150 kata):**
Perubahan dari V1 ke V2 menyadarkan saya bahwa sekadar menyembunyikan fungsi tidak sama dengan membatasi otorisasi. Pada asumsi V1, fungsi hanya diperiksa berdasarkan kondisi alur, tanpa memvalidasi siapa yang mengeksekusinya. Test `testVendorCannotApprove` berhasil menangkap bug potensial ketika fungsi dijalankan oleh pengguna yang tidak berhak. Risiko yang belum sepenuhnya teratasi adalah ketika seorang admin secara tidak sengaja atau sengaja mencabut role regulator tanpa menunjuk penggantinya, sehingga seluruh proses bisnis berhenti di tengah jalan (single point of failure pada admin). Melalui proses mutation check, saya juga melihat secara langsung bahwa automated test berfungsi sebagai sabuk pengaman utama sebelum kode dirilis.
