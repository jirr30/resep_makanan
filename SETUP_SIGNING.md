# Panduan Setup Signing untuk Play Store

## Langkah 1: Buat Keystore

Jalankan perintah ini di terminal (hanya sekali, simpan filenya dengan aman!):

```bash
keytool -genkey -v \
  -keystore resepku-release.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias resepku-key \
  -storepass PASSWORD_TOKO_KAMU \
  -keypass PASSWORD_KEY_KAMU \
  -dname "CN=ResepKu, OU=Mobile, O=NamaPerusahaan, L=Jakarta, S=DKI Jakarta, C=ID"
```

Ganti:
- `PASSWORD_TOKO_KAMU` → password untuk keystore (ingat baik-baik!)
- `PASSWORD_KEY_KAMU` → password untuk key (bisa sama dengan password toko)

## Langkah 2: Encode Keystore ke Base64

```bash
base64 -w 0 resepku-release.jks > resepku-release-base64.txt
```

Salin isi file `resepku-release-base64.txt`.

## Langkah 3: Tambah GitHub Secrets

Buka repository GitHub → Settings → Secrets and variables → Actions → New repository secret

Tambahkan secrets berikut:

| Nama Secret | Nilai |
|---|---|
| `KEYSTORE_BASE64` | Isi dari file `resepku-release-base64.txt` |
| `STORE_PASSWORD` | Password keystore kamu |
| `KEY_PASSWORD` | Password key kamu |
| `KEY_ALIAS` | `resepku-key` (atau alias yang kamu pakai) |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | JSON service account Google Play (lihat langkah 4) |

## Langkah 4: Setup Google Play Service Account

1. Buka [Google Play Console](https://play.google.com/console)
2. Pilih aplikasi kamu
3. Buka **Setup → API access**
4. Klik **Link to a Google Cloud Project** → buat project baru atau pilih yang ada
5. Di Google Cloud Console, buka **IAM & Admin → Service Accounts**
6. Buat service account baru dengan role **Editor**
7. Buat key baru (format JSON) → download file JSON
8. Kembali ke Play Console → Grant access ke service account tersebut dengan permission **Release Manager**
9. Salin seluruh isi file JSON ke secret `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`

## Langkah 5: Cara Release

### Cara 1 — Auto release saat push tag:
```bash
git tag v1.0.0
git push origin v1.0.0
```

GitHub Actions akan otomatis:
1. Jalankan test
2. Build AAB + APK dengan signing
3. Buat GitHub Release
4. Upload ke Play Store (Internal Testing)

### Cara 2 — Manual trigger:
1. Buka tab Actions di GitHub
2. Pilih workflow "Build & Release Android"
3. Klik "Run workflow"
4. Centang "Deploy ke Play Store?" jika ingin upload

## Catatan Penting

- **JANGAN commit** file `resepku-release.jks` ke repository!
- **JANGAN commit** file `key.properties` ke repository!
- Tambahkan ke `.gitignore`:
  ```
  *.jks
  *.keystore
  android/key.properties
  ```
- Simpan file `.jks` di tempat yang aman (Google Drive, dll.)
- Jika keystore hilang, kamu **tidak bisa update** aplikasi di Play Store

## Track Play Store

- `internal` → Internal Testing (hanya email terdaftar)
- `alpha` → Closed Testing (grup alpha)
- `beta` → Open Testing (publik terbatas)
- `production` → Rilis ke semua pengguna

Edit file `.github/workflows/build-release.yml` bagian `track:` untuk mengubah target.
