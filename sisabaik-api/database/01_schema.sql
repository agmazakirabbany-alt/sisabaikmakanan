BEGIN;

DROP TABLE IF EXISTS pengambilan, detail_pesanan, pesanan,
penawaran, penyedia, pengguna CASCADE;

CREATE TABLE pengguna (
id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
nama_lengkap VARCHAR(100) NOT NULL,
email VARCHAR(254) NOT NULL UNIQUE,
peran VARCHAR(20) NOT NULL
CHECK (peran IN ('penyedia', 'pembeli')),
aktif BOOLEAN NOT NULL DEFAULT TRUE,
dibuat_pada TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE penyedia (
id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
pengguna_id BIGINT NOT NULL UNIQUE
REFERENCES pengguna(id)
ON UPDATE CASCADE ON DELETE RESTRICT,
nama_usaha VARCHAR(120) NOT NULL,
alamat TEXT NOT NULL,
nomor_telepon VARCHAR(20) NOT NULL,
status_verifikasi VARCHAR(20) NOT NULL DEFAULT 'menunggu'
CHECK (status_verifikasi IN ('menunggu', 'terverifikasi', 'ditolak')),
dibuat_pada TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE penawaran (
id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
penyedia_id BIGINT NOT NULL
REFERENCES penyedia(id)
ON UPDATE CASCADE ON DELETE RESTRICT,
nama VARCHAR(120) NOT NULL,
kategori VARCHAR(40) NOT NULL,
harga_normal NUMERIC(12,0) NOT NULL CHECK (harga_normal > 0),
harga_penawaran NUMERIC(12,0) NOT NULL
CHECK (harga_penawaran >= 0 AND harga_penawaran <= harga_normal),
stok INTEGER NOT NULL CHECK (stok >= 0),
satuan VARCHAR(20) NOT NULL,
status VARCHAR(20) NOT NULL DEFAULT 'aktif'
CHECK (status IN ('draft', 'aktif', 'habis', 'kedaluwarsa')),
berakhir_pada TIMESTAMPTZ NOT NULL,
dibuat_pada TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
CONSTRAINT uq_penawaran_id_penyedia UNIQUE (id, penyedia_id),
CONSTRAINT ck_penawaran_waktu
CHECK (berakhir_pada > dibuat_pada)
);

CREATE TABLE pesanan (
id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
pembeli_id BIGINT NOT NULL
REFERENCES pengguna(id)
ON UPDATE CASCADE ON DELETE RESTRICT,
penyedia_id BIGINT NOT NULL
REFERENCES penyedia(id)
ON UPDATE CASCADE ON DELETE RESTRICT,
status VARCHAR(30) NOT NULL DEFAULT 'menunggu-konfirmasi'
CHECK (status IN (
'menunggu-konfirmasi', 'dikonfirmasi', 'siap-diambil',
'selesai', 'dibatalkan'
)),
total_transaksi NUMERIC(12,0) NOT NULL DEFAULT 0
CHECK (total_transaksi >= 0),
nilai_stok_terselamatkan NUMERIC(12,0) NOT NULL DEFAULT 0
CHECK (nilai_stok_terselamatkan >= total_transaksi),
dibuat_pada TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
CONSTRAINT uq_pesanan_id_penyedia UNIQUE (id, penyedia_id)
);

CREATE TABLE detail_pesanan (
pesanan_id BIGINT NOT NULL,
penawaran_id BIGINT NOT NULL,
penyedia_id BIGINT NOT NULL,
kuantitas INTEGER NOT NULL CHECK (kuantitas > 0),
harga_normal_satuan NUMERIC(12,0) NOT NULL
CHECK (harga_normal_satuan > 0),
harga_penawaran_satuan NUMERIC(12,0) NOT NULL
CHECK (
harga_penawaran_satuan >= 0
AND harga_penawaran_satuan <= harga_normal_satuan
),
subtotal NUMERIC(12,0) GENERATED ALWAYS AS
(kuantitas * harga_penawaran_satuan) STORED,
nilai_stok NUMERIC(12,0) GENERATED ALWAYS AS
(kuantitas * harga_normal_satuan) STORED,
PRIMARY KEY (pesanan_id, penawaran_id),
FOREIGN KEY (pesanan_id, penyedia_id)
REFERENCES pesanan(id, penyedia_id)
ON UPDATE CASCADE ON DELETE CASCADE,
FOREIGN KEY (penawaran_id, penyedia_id)
REFERENCES penawaran(id, penyedia_id)
ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE pengambilan (
id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
pesanan_id BIGINT NOT NULL UNIQUE
REFERENCES pesanan(id)
ON UPDATE CASCADE ON DELETE CASCADE,
kode VARCHAR(20) NOT NULL UNIQUE,
jadwal_pada TIMESTAMPTZ NOT NULL,
diambil_pada TIMESTAMPTZ,
status VARCHAR(20) NOT NULL DEFAULT 'terjadwal'
CHECK (status IN ('terjadwal', 'diambil', 'gagal')),
CHECK (diambil_pada IS NULL OR diambil_pada >= jadwal_pada)
);

CREATE INDEX idx_penawaran_penyedia ON penawaran(penyedia_id);
CREATE INDEX idx_penawaran_status_berakhir
ON penawaran(status, berakhir_pada);
CREATE INDEX idx_pesanan_pembeli ON pesanan(pembeli_id);
CREATE INDEX idx_pesanan_penyedia ON pesanan(penyedia_id);
CREATE INDEX idx_detail_penawaran ON detail_pesanan(penawaran_id);

COMMIT;

BEGIN;

INSERT INTO pengguna (nama_lengkap, email, peran) VALUES
('Rina Putri', 'rina.penyedia@example.test', 'penyedia'),
('Budi Santoso', 'budi.penyedia@example.test', 'penyedia'),
('Siti Rahma', 'siti.pembeli@example.test', 'pembeli'),
('Andi Saputra', 'andi.pembeli@example.test', 'pembeli');

INSERT INTO penyedia (
pengguna_id, nama_usaha, alamat, nomor_telepon, status_verifikasi
) VALUES
(1, 'Lapau Uni Rina', 'JI. Merpati No. 10, Padang', '081200000001', 'terverifikasi'),
(2, 'Roti Minang', 'Jl. Sudirman No. 21, Padang', '081200000002', 'terverifikasi');

INSERT INTO penawaran (
penyedia_id, nama, kategori, harga_normal, harga_penawaran,
stok, satuan, status, berakhir_pada
) VALUES
(
2, 'Paket Roti Sore', 'roti', 30000, 15000,
6, 'paket', 'aktif', CURRENT_TIMESTAMP + INTERVAL '1 day'
),
(
1, 'Nasi Padang Hemat', 'makanan-siap-saji', 25000, 12000,
4, 'porsi', 'aktif', CURRENT_TIMESTAMP + INTERVAL '8 hours'
),
(
1, 'Sayur Layak Olah', 'bahan-segar', 18000, 0,
5, 'paket', 'aktif', CURRENT_TIMESTAMP + INTERVAL '12 hours'
);

INSERT INTO pesanan (
pembeli_id, penyedia_id, status, total_transaksi,
nilai_stok_terselamatkan
) VALUES
(3, 1, 'siap-diambil', 12000, 25000);

INSERT INTO detail_pesanan (
pesanan_id, penawaran_id, penyedia_id, kuantitas,
harga_normal_satuan, harga_penawaran_satuan
) VALUES
(1, 2, 1, 1, 25000, 12000);

INSERT INTO pengambilan (
pesanan_id, kode, jadwal_pada, status
) VALUES
(1, 'AMBIL-0001', CURRENT_TIMESTAMP + INTERVAL '2 hours', 'terjadwal');

COMMIT;