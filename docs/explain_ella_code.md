# Penjelasan: `00_ella_code.ipynb`

Notebook ini adalah pipeline lengkap klasifikasi citra sampah 12 kelas menggunakan dua pendekatan: **SVM (ML klasik)** dan **MobileNetV2 (Deep Learning)**.

---

## Dataset

- **Sumber:** Garbage Classification (12 Classes) — Kaggle (`mostafaabla/garbage-classification`)
- **Total:** 15.515 gambar, 12 kelas: `battery`, `biological`, `brown-glass`, `cardboard`, `clothes`, `green-glass`, `metal`, `paper`, `plastic`, `shoes`, `trash`, `white-glass`
- **Imbalance:** 8.8x (kelas terbesar: `clothes` 5.325 gambar; terkecil: `brown-glass` 607 gambar)

---

## Tahap-tahap Pipeline

### Tahap 1 — Akuisisi & Eksplorasi Dataset
- Kumpulkan semua path gambar dari 12 folder kelas
- Tampilkan distribusi kelas (bar chart), grid sampel gambar per kelas, dan analisis resolusi (sampel 400 gambar)
- Resolusi bervariasi → semua akan di-resize ke 224×224

### Tahap 2 — Praproses
Fungsi `preprocess_image(path)`:
1. Load via OpenCV (BGR)
2. Konversi BGR → RGB
3. Resize ke 224×224 (INTER_AREA)
4. Normalisasi ke `[0, 1]` (float32)

### Tahap 3 — Image Enhancement (Histogram Equalization)
Fungsi `apply_histogram_equalization(img_norm)`:
- Konversi RGB → LAB color space
- Terapkan `cv2.equalizeHist` **hanya pada channel L** (luminance)
- Konversi balik ke RGB
- Tujuan: tingkatkan kontras tanpa mengubah kromatisitas warna

**Formula HE:**
```
s_k = (L-1) * Σ p_r(r_j)  untuk j=0..k
```

### Tahap 4 — Segmentasi (Otsu Thresholding)
Fungsi `apply_otsu_segmentation(img_norm)`:
1. Konversi ke grayscale → Gaussian blur (5×5)
2. Otsu thresholding → binary mask
3. Morphological cleanup: `MORPH_CLOSE` (tutup lubang) + `MORPH_OPEN` (hapus noise), kernel ellipse 7×7
4. Terapkan mask ke gambar → isolasi objek sampah dari background

**Formula Otsu:**
```
σ²_B(t) = ω₀(t) · ω₁(t) · [μ₀(t) - μ₁(t)]²
```

### Tahap 5 — Ekstraksi Fitur (untuk SVM)
Tiga fitur diekstraksi dari citra tersegmentasi:

| Fitur | Metode | Dimensi |
|---|---|---|
| Warna | HSV Histogram (32 bin × 3 channel) | 96 |
| Tekstur | LBP uniform (radius=3, 24 points) | 26 |
| Bentuk | HOG (9 orientasi, 16×16 px/cell, 2×2 cells/block) | 6.084 |
| **Total** | | **6.206** |

Ketiga vektor di-concatenate menjadi satu vektor per gambar.

### Pembagian Dataset
Split **satu kali** (digunakan oleh SVM dan CNN — fair comparison):
- Train: 70% (10.866 gambar)
- Validation: 15% (2.321 gambar)
- Test: 15% (2.328 gambar)
- Stratified split berdasarkan label

---

## Model

### Skenario A — SVM (ML Klasik)
- Ekstraksi fitur batch untuk semua split (~17 menit)
- `StandardScaler` pada fitur
- `SVC(kernel='rbf', C=10, gamma='scale', probability=True)`
- Waktu latih: ~85 menit
- **Validation accuracy: ~63.68%**

### Skenario B — MobileNetV2 (Deep Learning)
- Data augmentation pada train: rotasi, shift, flip, zoom, brightness
- Base model: MobileNetV2 pretrained ImageNet, `include_top=False`
- Freeze semua layer **kecuali 30 layer terakhir** (fine-tuning)
- Head tambahan: `GlobalAveragePooling2D → Dropout(0.3) → Dense(256, relu) → Dropout(0.2) → Dense(12, softmax)`
- Total params: 2.589.004, trainable: 35 layer
- Optimizer: Adam (lr=1e-4), loss: categorical_crossentropy
- Callbacks: `EarlyStopping(patience=6)` + `ReduceLROnPlateau(patience=3)`
- Max epoch: 30

---

## Tahap 7 — Evaluasi
Evaluasi pada **test set yang sama** untuk kedua model:
- Metrik: Accuracy, Precision, Recall, F1-Score (weighted)
- Confusion Matrix berdampingan (SVM vs MobileNetV2)
- MobileNetV2 unggul atas SVM (fitur otomatis vs handcrafted)

---

## Tahap 8 — Analisis Lanjutan

### 8.1 WITH vs WITHOUT Enhancement
- Latih ulang SVM **tanpa** HE (skip step 3, langsung segmentasi)
- Bandingkan akurasi → kuantifikasi dampak HE

### 8.2 Ablasi Fitur
Uji SVM dengan kombinasi fitur:
- Warna saja (HSV)
- Tekstur saja (LBP)
- Bentuk saja (HOG)
- Warna + Tekstur
- Warna + Bentuk
- Semua fitur (baseline)

### 8.3 Per-class Accuracy (SVM)
- Hitung akurasi per kelas → identifikasi kelas yang sering salah klasifikasi
- Kelas sulit: `paper` vs `cardboard`, `white-glass` vs `plastic` (kemiripan visual tinggi)

### 8.4 Visualisasi Kesalahan
- Tampilkan 8 contoh gambar yang salah prediksi oleh SVM (true label vs predicted label)

---

## Kesimpulan

| Aspek | SVM | MobileNetV2 |
|---|---|---|
| Fitur | Handcrafted (HSV+LBP+HOG) | Otomatis dari piksel |
| Kompleksitas | Rendah | Tinggi |
| Interpretabilitas | Tinggi (ablasi fitur bisa dilakukan) | Rendah (black box) |
| Performa | Lebih rendah | Lebih tinggi |

**Temuan utama:**
- HE meningkatkan akurasi SVM
- Fitur warna (HSV) paling efektif untuk kelas dengan warna khas (green-glass, brown-glass, metal)
- MobileNetV2 unggul karena ekstraksi fitur hierarkis otomatis

**Saran pengembangan:** data augmentation lebih agresif, class weighting, CLAHE sebagai alternatif HE, ensemble SVM+CNN, segmentasi adaptif (GrabCut/SAM).
