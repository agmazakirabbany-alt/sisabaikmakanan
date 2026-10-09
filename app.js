"use strict";

// Format pencatatan mata uang Rupiah secara global
const rupiah = new Intl.NumberFormat("id-ID", {
  style: "currency",
  currency: "IDR",
  maximumFractionDigits: 0
});

// Menjalankan fungsi setelah seluruh dokumen HTML selesai dimuat
document.addEventListener("DOMContentLoaded", () => {
  siapkanKatalog();
  siapkanValidasiPenawaran();
});

// Fungsi utama untuk mengambil data JSON dan mengatur filter/pencarian
async function siapkanKatalog() {
  const wadah = document.querySelector("#daftar-penawaran");
  if (!wadah) return; // Guard clause jika elemen tidak ditemukan di halaman ini

  const status = document.querySelector("#status-katalog");
  const inputCari = document.querySelector("#kata-kunci");
  const pilihKategori = document.querySelector("#filter-kategori");
  const keranjang = [];

  try {
    // Mengambil data fiktif secara asinkron
    const respons = await fetch("data/penawaran.json");
    if (!respons.ok) throw new Error(`HTTP ${respons.status}`);
    const penawaran = await respons.json();

    // Fungsi untuk memfilter data berdasarkan input pengguna
    function perbaruiTampilan() {
      const kata = inputCari.value.trim().toLowerCase();
      const kategori = pilihKategori.value;

      const hasil = penawaran.filter((item) => {
        const cocokKata = `${item.nama} ${item.penyedia}`.toLowerCase().includes(kata);
        const cocokKategori = kategori === "semua" || item.kategori === kategori;
        return cocokKata && cocokKategori;
      });

      // Menampilkan kartu hasil filter ke antarmuka
      renderKartu(hasil, wadah, status, keranjang);
    }

    // Menghubungkan event input dengan fungsi pembaruan tampilan
    inputCari.addEventListener("input", perbaruiTampilan);
    pilihKategori.addEventListener("change", perbaruiTampilan);
    
    // Jalankan pertama kali untuk memuat semua data awal
    perbaruiTampilan();

  } catch (error) {
    // Menangani state error jika JSON gagal dimuat
    status.textContent = "Data gagal dimuat. Jalankan proyek melalui server lokal.";
    status.classList.add("error-message");
    console.error("Gagal memuat penawaran:", error);
  }
}

// Fungsi untuk membuat elemen kartu produk di DOM secara dinamis
function renderKartu(data, wadah, status, keranjang) {
  wadah.replaceChildren(); // Mengosongkan sisa kartu sebelumnya
  status.textContent = `${data.length} penawaran ditemukan.`;

  data.forEach((item) => {
    const artikel = document.createElement("article");
    artikel.className = "offer-card";
    artikel.innerHTML = `
      <div class="offer-card__visual" aria-hidden="true"></div>
      <div class="offer-card__content">
        <span class="badge">${item.labelKategori}</span>
        <h3>${item.nama}</h3>
        <p class="offer-card__meta">${item.penyedia} · ${item.stok} ${item.satuan}</p>
        <p class="offer-card__price">
          <del>${rupiah.format(item.hargaNormal)}</del>
          <strong>${item.hargaPenawaran === 0 ? "Tanpa biaya" : rupiah.format(item.hargaPenawaran)}</strong>
        </p>
        <button class="button" type="button" data-id="${item.id}">Tambah</button>
      </div>`;

    // Event ketika tombol 'Tambah' diklik untuk memperbarui ringkasan belanja
    artikel.querySelector("button").addEventListener("click", () => {
      keranjang.push(item);
      perbaruiRingkasan(keranjang);
    });

    wadah.append(artikel);
  });
}

// Fungsi dengan reduce() untuk menghitung total belanjaan di keranjang
function perbaruiRingkasan(keranjang) {
  const total = keranjang.reduce((jumlah, item) => jumlah + item.hargaPenawaran, 0);
  document.querySelector("#jumlah-item").textContent = keranjang.length;
  document.querySelector("#total-pesanan").textContent = rupiah.format(total);
}

// Fungsi validasi formulir lintas-kolom di halaman tawarkan-makanan.html
function siapkanValidasiPenawaran() {
  const form = document.querySelector("#form-penawaran");
  if (!form) return; // Guard clause jika form tidak ada di halaman aktif

  const normal = form.querySelector("#harga-normal");
  const penawaran = form.querySelector("#harga-pemulihan");

  function validasiHarga() {
    const hargaNormal = Number(normal.value);
    const hargaPenawaran = Number(penawaran.value);

    // Mengeset pesan error kustom (string kosong berarti form valid/tidak error)
    penawaran.setCustomValidity(
      hargaPenawaran > hargaNormal ? "Harga penawaran tidak boleh melebihi harga normal." : ""
    );
  }

  normal.addEventListener("input", validasiHarga);
  penawaran.addEventListener("input", validasiHarga);

  form.addEventListener("submit", (event) => {
    validasiHarga();
    if (!form.checkValidity()) {
      event.preventDefault(); // Menahan submit jika tidak logis
      form.reportValidity(); // Menampilkan balon pesan error dari browser
    }
  });
}
