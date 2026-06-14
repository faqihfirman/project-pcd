#set page(
  paper: "a4",
  margin: (x: 2.4cm, y: 2.6cm),
  numbering: "1",
)
#set text(size: 11pt, lang: "id", hyphenate: false)
#set par(justify: true, leading: 0.72em)
#show heading.where(level: 1): it => block(above: 1.4em, below: 0.7em)[
  #set text(size: 13.5pt, weight: "bold")
  #it
]
#show heading.where(level: 2): it => block(above: 1em, below: 0.5em)[
  #set text(size: 12pt, weight: "bold")
  #it
]
#set figure(supplement: [Gambar])
#show figure.caption: set text(size: 9.5pt, style: "italic")

// ====================== JUDUL ======================
#text(size: 18pt, weight: "bold")[Hasil dan Pembahasan]
#v(0.2em)
#text(size: 12pt, weight: "bold")[Klasifikasi Sampah dengan MobileNetV2 dan Image Enhancement Adaptif]
#v(0.3em)

#text(size: 9.5pt, style: "italic")[
  Berdasarkan eksperimen 05_citra_problem.ipynb (analisis masalah citra) dan
  04_mobile_net_fatures_enhancement.ipynb (ekstraksi fitur, enhancement, dan pemodelan).
]
#v(0.4em)
#line(length: 100%, stroke: 0.5pt + gray)
#v(0.4em)

Bab ini membahas tiga hal secara berurutan: (1) masalah kualitas citra yang teridentifikasi pada
dataset dan menjadi dasar kebutuhan enhancement, (2) hasil ekstraksi fitur serta image enhancement
yang diterapkan, dan (3) evaluasi performa model untuk tiap skenario pra-pemrosesan. Dataset terdiri
atas 12 kelas sampah (battery, biological, brown-glass, cardboard, clothes, green-glass, metal,
paper, plastic, shoes, trash, white-glass) dengan total lebih dari 15.000 citra.

// ====================== BAGIAN 1 ======================
= Karakteristik Citra Dataset yang Perlu ditangani

Untuk menentukan enhancement yang tepat, dilakukan analisis kuantitatif terhadap kualitas citra.
Sebanyak 150 citra per kelas (total 1.800 citra) disampel acak, lalu setiap citra diukur dengan
tujuh metrik objektif: blur (variance of Laplacian), noise (estimasi $sigma$ metode Immerkær),
pencahayaan (brightness rata-rata serta fraksi piksel gelap/jenuh), kontras (standar deviasi
luminansi), kepadatan tepi (edge density sebagai proksi background ramai), dan colorfulness
(metrik Hasler--Süsstrunk). Sebuah citra ditandai bermasalah bila melewati ambang yang ditetapkan
per metrik.

Secara keseluruhan dataset, proporsi citra bermasalah didominasi oleh masalah pencahayaan
berlebih (Terang) dan warna pudar, sebagaimana dirangkum pada @tbl-overall.

#figure(
  caption: [Persentase citra bermasalah pada keseluruhan dataset (1.800 sampel).],
  table(
    columns: (auto, auto),
    align: (left, right),
    inset: 6pt,
    stroke: 0.4pt + gray,
    table.header([*Jenis Masalah*], [*Persentase*]),
    [Terang (overexposure)], [56,7 %],
    [Warna pudar], [29,3 %],
    [Kontras rendah], [21,3 %],
    [Noise], [20,1 %],
    [Background ramai], [17,8 %],
    [Blur], [4,8 %],
    [Gelap (underexposure)], [1,4 %],
  ),
) <tbl-overall>

Distribusi tiap metrik antar kelas ditunjukkan pada @fig-box. Terlihat sebaran blur (variance
of Laplacian) sangat lebar antar kelas, sementara brightness beberapa kelas (mis. battery, trash,
brown/green-glass) terkonsentrasi tinggi, menegaskan masalah overexposure.

#figure(
  image("images/nb05_cell10.png", width: 75%),
  caption: [Boxplot distribusi enam metrik kualitas citra antar kelas. Garis putus-putus = ambang batas.],
) <fig-box>

Inti analisis adalah heatmap persentase masalah per kelas (@fig-heat). Sel yang lebih gelap
menandakan masalah lebih dominan, dan inilah dasar pemetaan enhancement per kelas.

#figure(
  image("images/nb05_cell12.png", width: 65%),
  caption: [Persentase citra bermasalah per kelas. Dipakai untuk menentukan enhancement spesifik tiap kelas.],
) <fig-heat>

Dari @fig-heat terlihat pola yang jelas: masalah Terang hampir merata di semua kelas dan ekstrem
pada battery (92%) serta trash (89%); kontras rendah menonjol pada trash (69%),
white-glass (53%), dan plastic (42%); noise tinggi pada paper (55%), battery (36%),
clothes (35%), dan shoes (31%); background ramai dominan pada biological (51%) dan
paper (51%); sedangkan warna pudar paling parah pada white-glass (77%) dan battery (57%).
Rangkuman masalah dominan ($>= 25%$) dan rekomendasi penanganannya disajikan pada @tbl-reco.

#figure(
  caption: [Masalah dominan per kelas dan rekomendasi enhancement.],
  table(
    columns: (auto, 1fr, 1.3fr),
    align: (left, left, left),
    inset: 5pt,
    stroke: 0.4pt + gray,
    table.header([*Kelas*], [*Masalah dominan*], [*Rekomendasi enhancement*]),
    [battery], [Noise, Terang, Warna pudar], [Denoising; Gamma↓; Saturation/White balance],
    [biological], [Noise, Terang, Background ramai], [Denoising; Gamma↓; Segmentasi background],
    [brown-glass], [Terang], [Gamma↓ / tone mapping],
    [cardboard], [Terang], [Gamma↓ / tone mapping],
    [clothes], [Noise, Background ramai], [Denoising; Segmentasi background],
    [green-glass], [Terang], [Gamma↓ / tone mapping],
    [metal], [Terang, Warna pudar], [Gamma↓; Saturation/White balance],
    [paper], [Noise, Terang, Bg ramai, Warna pudar], [Denoising; Gamma↓; Saturation; Segmentasi],
    [plastic], [Terang, Kontras rendah, Warna pudar], [CLAHE/Contrast stretch; Gamma↓; Saturation],
    [shoes], [Noise, Terang, Warna pudar], [Denoising; Gamma↓; Saturation],
    [trash], [Terang, Kontras rendah, Warna pudar], [CLAHE/Contrast stretch; Gamma↓; Saturation],
    [white-glass], [Terang, Kontras rendah, Warna pudar], [CLAHE/Contrast stretch; Gamma↓; Saturation],
  ),
) <tbl-reco>

Contoh visual citra paling ekstrem untuk masing-masing masalah ditampilkan pada @fig-gal, yang
mengonfirmasi bahwa metrik objektif memang menangkap masalah nyata (mis. citra terang menyilaukan,
noise kasar, kontras datar, dan warna kusam).

#figure(
  grid(
    columns: 1,
    row-gutter: 5pt,
    image("images/nb05_gallery3.png", width: 80%),
    image("images/nb05_gallery1.png", width: 80%),
    image("images/nb05_gallery4.png", width: 80%),
    image("images/nb05_gallery6.png", width: 80%),
  ),
  caption: [Contoh citra bermasalah paling ekstrem: (atas ke bawah) Terang, Noise, Kontras rendah, Warna pudar.],
) <fig-gal>

Rata-rata jumlah masalah yang dialami satu citra sekaligus (severity) divisualisasikan pada
@fig-sev. Mayoritas citra memiliki 1 hingga 2 masalah, namun beberapa kelas menumpuk hingga 3 masalah.

#figure(
  image("images/nb05_cell14.png", width: 78%),
  caption: [Severity: rata-rata jumlah masalah per citra tiap kelas (kiri) dan distribusinya (kanan).],
) <fig-sev>

// ====================== BAGIAN 2 ======================
= Hasil Fitur Ekstraksi dan Image Enhancement

== Penetapan Ambang Enhancement (EDA)

Enhancement dirancang adaptif, yakni hanya diterapkan saat sebuah citra benar-benar bermasalah,
agar tidak merusak citra yang sudah baik. Ambang ditetapkan dari distribusi metrik pada data latih
(@fig-thr). Ambang ketajaman diambil dari persentil-10 variance of Laplacian, sedangkan batas
white balance diturunkan dari rasio kanal warna ($"mean" plus.minus 1.5 sigma$):

#figure(
  caption: [Ambang batas hasil EDA untuk enhancement adaptif.],
  table(
    columns: (auto, auto, 1.4fr),
    align: (left, right, left),
    inset: 6pt,
    stroke: 0.4pt + gray,
    table.header([*Parameter*], [*Nilai*], [*Fungsi*]),
    [Laplacian var. threshold], [95,64], [Di bawah ini citra dianggap blur, perlu sharpening/CLAHE],
    [RGB ratio lower], [0,742], [Batas bawah rasio kanal untuk koreksi white balance],
    [RGB ratio upper], [1,253], [Batas atas rasio kanal untuk koreksi white balance],
  ),
) <tbl-thr>

#figure(
  image("images/nb04_cell10.png", width: 62%),
  caption: [Analisis distribusi metrik (variance of Laplacian dan rasio kanal) untuk penetapan ambang.],
) <fig-thr>

== Pipeline Enhancement dan Hasilnya

Berdasarkan masalah dominan (@tbl-reco), pipeline enhancement menggabungkan CLAHE (perbaikan
kontras pada channel L ruang LAB), Non-local Means denoising, dan gray-world white balance,
yang diterapkan secara kondisional sesuai ambang @tbl-thr. Perbandingan citra sebelum dan sesudah
enhancement disajikan pada @fig-ba.

#figure(
  image("images/nb04_cell14.png", width: 42%),
  caption: [Perbandingan citra sebelum (kiri) dan sesudah (kanan) enhancement pada delapan sampel lintas kelas.],
) <fig-ba>

Pada @fig-ba terlihat hasil enhancement: detail kembali tegas pada citra yang semula buram,
kontras meningkat pada objek berkilau/transparan (botol kaca, kaleng metal), serta warna menjadi
lebih netral setelah white balance. Efek paling kentara muncul pada kelas dengan masalah kontras
rendah dan warna pudar (plastic, white-glass, metal), konsisten dengan temuan @fig-heat.

== Ekstraksi Fitur dengan MobileNetV2

Ekstraksi fitur memanfaatkan MobileNetV2 (pra-latih ImageNet) sebagai backbone. Lapisan
konvolusi menghasilkan peta fitur yang diringkas oleh Global Average Pooling menjadi vektor
fitur 1280 dimensi, lalu diteruskan ke kepala klasifikasi (Dense 256 + Dropout) berukuran 12 kelas.
Strategi fine-tuning 30 lapisan terakhir dipakai agar fitur tingkat tinggi menyesuaikan domain
sampah tanpa kehilangan representasi umum dari ImageNet. Seluruh masukan dinormalisasi ke rentang
$[-1, 1]$ melalui preprocess_input, dengan augmentasi (rotasi, geser, zoom, flip) pada data latih.

// ====================== BAGIAN 3 ======================
= Evaluasi per Skenario

Dua skenario pra-pemrosesan dibandingkan secara adil (arsitektur, hyperparameter, dan split data
identik):

- Skenario A (Baseline): citra hanya dinormalisasi (preprocess_input) tanpa enhancement.
- Skenario B (Enhanced): citra melewati pipeline enhancement (CLAHE + denoise + white balance) sebelum normalisasi.

Ringkasan metrik kedua skenario pada test set (2.340 citra) disajikan pada @tbl-cmp.

#figure(
  caption: [Perbandingan performa Skenario A (baseline) vs Skenario B (enhanced).],
  table(
    columns: (1.4fr, auto, auto),
    align: (left, center, center),
    inset: 6pt,
    stroke: 0.4pt + gray,
    table.header([*Metrik*], [*A (Baseline)*], [*B (Enhanced)*]),
    [Train Accuracy], [98,83 %], [99,31 %],
    [Val Accuracy], [96,04 %], [95,78 %],
    [Test Accuracy], [95,98 %], [95,81 %],
    [Train Loss], [0,0359], [0,0215],
    [Val Loss], [0,1857], [0,1997],
    [Test Loss], [0,1727], [0,1743],
  ),
) <tbl-cmp>

Kurva pelatihan dan loss kedua skenario dibandingkan pada @fig-curve, sedangkan confusion matrix
ternormalisasi keduanya pada @fig-cm.

#figure(
  image("images/nb04_cell45.png", width: 80%),
  caption: [Kurva accuracy (kiri) dan loss (kanan): Skenario A vs Skenario B sepanjang 15 epoch.],
) <fig-curve>

#figure(
  image("images/nb04_cell46.png", width: 88%),
  caption: [Confusion matrix ternormalisasi: Skenario A (kiri) vs Skenario B (kanan).],
) <fig-cm>

Untuk melihat dampak enhancement pada level kelas, F1-score per kelas kedua skenario dirangkum
pada @tbl-f1.

#figure(
  caption: [F1-score per kelas: Skenario A vs Skenario B (selisih B−A).],
  table(
    columns: (auto, auto, auto, auto),
    align: (left, center, center, center),
    inset: 5pt,
    stroke: 0.4pt + gray,
    table.header([*Kelas*], [*A*], [*B*], [*Δ*]),
    [battery], [0,97], [0,98], [+0,01],
    [biological], [0,98], [0,97], [−0,01],
    [brown-glass], [0,93], [0,94], [+0,01],
    [cardboard], [0,97], [0,98], [+0,01],
    [clothes], [0,99], [0,99], [0,00],
    [green-glass], [0,94], [0,92], [−0,02],
    [metal], [0,88], [0,91], [+0,03],
    [paper], [0,94], [0,94], [0,00],
    [plastic], [0,87], [0,84], [−0,03],
    [shoes], [0,97], [0,97], [0,00],
    [trash], [0,98], [0,98], [0,00],
    [white-glass], [0,88], [0,88], [0,00],
    [Macro avg], [0,94], [0,94], [0,00],
  ),
) <tbl-f1>

== Pembahasan

Secara agregat, kedua skenario mencapai akurasi test yang nyaris setara (95,98% vs 95,81%),
dengan baseline sedikit unggul pada validasi/test (selisih $approx 0,2$ poin). Artinya, pada
arsitektur transfer-learning yang kuat seperti MobileNetV2, enhancement global tidak serta-merta
meningkatkan akurasi keseluruhan, sebab backbone pra-latih sudah cukup robust terhadap variasi
pencahayaan dan noise ringan.

Namun pada level kelas (@tbl-f1) efek enhancement bersifat selektif dan sesuai prediksi analisis
masalah: kelas metal (F1 +0,03) dan battery (+0,01), yang didominasi masalah warna pudar dan
overexposure, paling diuntungkan oleh kombinasi white balance dan koreksi pencahayaan. Sebaliknya,
plastic (−0,03) dan green-glass (−0,02) sedikit menurun. Enhancement kontras agresif pada objek
transparan/reflektif justru dapat memperkuat artefak dan mengaburkan batas antar kelas kaca/plastik
yang memang mirip secara visual, terlihat pula pada Train Loss B yang lebih rendah (0,0215) namun
Val Loss B lebih tinggi (0,1997), indikasi sedikit overfitting pada citra yang sudah dipertajam.

Kesimpulan praktis: enhancement sebaiknya diterapkan selektif per kelas/kondisi (seperti pemetaan
@tbl-reco) alih-alih seragam global, dan dilengkapi penanganan background ramai (segmentasi/cropping)
yang belum dicakup pipeline fotometrik saat ini, terutama untuk kelas biological dan paper yang
masih menjadi sumber kesalahan klasifikasi pada @fig-cm.
