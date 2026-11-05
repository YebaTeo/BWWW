from pathlib import Path
import json
root=Path(__file__).resolve().parent.parent
# Original compact learning copy; research pointers are kept with each phase.
data=[
('Narawas','narawas','Narawas','Memilih lahan huma','Awali perjalanan dengan mengenali batas lahan.','Periksa tiga petak. Pilih petak yang tersedia menurut aturan adat pada peta contoh ini.','Pemilihan lahan memperhatikan kondisi tanah dan batas adat. Narawas juga memiliki makna ritual; latihan ini hanya mengenalkan pemilihan tempat.','Petak huma ditandai; kawasan lindung tetap terjaga.',None,['S1','S2']),
('Nyacar','nyacar','Nyacar','Menyiapkan lahan secara selektif','Amati semak, cabang, dan pohon yang dipertahankan.','Ketuk empat bagian bertanda tebas. Biarkan pohon berguna tetap berdiri.','Nyacar, nuar, dan nutuh mencakup penebasan, penebangan terpilih, serta pemangkasan. Persiapan lahan dilakukan secara selektif.','Lahan lebih terbuka, pohon berguna tetap ada.',None,['S1']),
('Ngaganggang','ngaganggang','Ngaganggang','Mengeringkan hasil tebasan','Hasil tebasan masih basah. Perhatikan perubahan saat waktu berlalu.','Geser garis waktu dan kunjungi keadaan basah, mulai kering, lalu kering. Tombol keadaan juga tersedia.','Ranting dan daun yang ditebas dibiarkan mengering. Menunggu merupakan bagian dari persiapan huma.','Hasil tebasan telah kering.',None,['S1']),
('Ngahuru','ngahuru','Ngahuru / ngaduruk','Memahami urutan persiapan','Kenali perubahan lahan sebelum penanaman.','Pilih kartu, lalu pilih posisi urutannya: tebasan, tebasan kering, lahan setelah pembakaran.','Pembakaran tebasan kering termasuk dalam urutan persiapan huma yang dijelaskan sumber. Di sini kita mempelajari konteksnya, tanpa menirukan pembakaran.','Urutan persiapan lahan tersusun.',None,['S1']),
('Ngored','ngored','Ngored','Merawat padi muda','Setelah beberapa waktu, padi muda tumbuh bersama tumbuhan lain.','Lihat contoh: padi berdaun ramping tegak, gulma bergambar daun lebar. Singkirkan empat gulma, pertahankan padi.','Penyiangan mengurangi persaingan tumbuhan lain dengan padi. Ngored dapat berulang selama pertumbuhan. Ngirab sawan memiliki makna ritual tersendiri.','Gulma berkurang dan padi muda dipertahankan.','Setelah beberapa waktu · padi muda tumbuh',['S1','S2']),
('NgubaranPare','ngubaranPare','Ngubaran pare','Mengenal tumbuhan dalam perawatan','Pengetahuan tumbuhan hadir dalam masa perawatan padi.','Pelajari kartu acuan. Pilih sebuah ilustrasi, lalu nama yang cocok. Cocokkan ketiganya.','Mengkudu, laja, dan kelapa dicatat dalam perawatan tradisional. Ngubaran pare beririsan dengan penyiangan dan memiliki makna budaya; ini bukan resep atau janji kesembuhan.','Tiga tumbuhan dikenali berdasarkan kartu acuan.',None,['S2']),
('Dibuat','dibuat','Dibuat / ngetem','Memanen dengan hati-hati','Padi telah melewati masa tumbuh dan kini menguning.','Arahkan etem/ani-ani dengan mengetuk empat malai matang.','Etem atau ani-ani digunakan untuk memanen malai dengan hati-hati. Mipit adalah ritual yang berkaitan dengan panen, berbeda dari tindakan memotong malai.','Malai terkumpul bersama tangkai dan bulirnya.','Setelah masa pertumbuhan · padi matang',['S1','S2']),
('DryingRice','dryingRice','Mengeringkan padi','Menyiapkan hasil panen','Hasil panen perlu dikeringkan sebelum disimpan.','Pilih kelompok padi, lalu tempat kosong di rak bambu. Tempatkan ketiganya.','Padi dijemur pada rak bambu sebelum dibawa ke leuit. Pengeringan membantu menyiapkan padi untuk penyimpanan.','Setelah beberapa waktu, padi kering siap diikat dan dibawa.',None,['S3']),
('Ngunjal','ngunjal','Ngunjal','Membawa panen menuju leuit','Ikuti perjalanan padi dari huma menuju tempat penyimpanan.','Ketuk tiga titik jalan secara berurutan: tepi huma, jalan pulang, lalu leuit.','Ngunjal mengenalkan pengangkutan panen menuju penyimpanan. Perjalanan ini mengajak kita menghargai tenaga yang diperlukan untuk membawa hasil huma.','Ikatan padi tiba di dekat leuit.',None,['S3','S1']),
('NgaleuitkeunPare','ngaleuitkeunPare','Ngaleuitkeun pare','Menyimpan padi di leuit','Perjalanan panen berakhir di tempat penyimpanan.','Pilih ikatan padi, lalu ruang pada potongan ilustrasi leuit. Tiga posisi ini hanya alat bantu belajar.','Leuit menyimpan padi sebagai cadangan rumah tangga dan untuk keperluan adat. Penyimpanan berbeda dari ritual ngadiukeun pare yang menyertainya.','Padi tersimpan di leuit.',None,['S3','S2'])]
for folder,pid,title,subtitle,intro,instruction,explanation,result,cue,sources in data:
 d=root/'BeBaduy/Features/Phases'/folder; (d/'Resources').mkdir(parents=True,exist_ok=True)
 q=lambda s:json.dumps(s,ensure_ascii=False)
 text=f'''enum {folder}Content {{
    static let value = PhaseContent(id: .{pid}, title: {q(title)}, subtitle: {q(subtitle)},
        introduction: {q(intro)}, instruction: {q(instruction)},
        explanation: {q(explanation)}, result: {q(result)}, timeCue: {q(cue) if cue else 'nil'}, sourceIDs: [{', '.join(q(x) for x in sources)}])
}}
'''
 (d/f'{folder}Content.swift').write_text(text)
 for suffix,component in [('Introduction','IntroductionText'),('Description','ReflectionText')]:
  (d/f'{folder}{suffix}View.swift').write_text(f'import SwiftUI\nstruct {folder}{suffix}View: View {{ var body: some View {{ {component}(content: {folder}Content.value) }} }}\n')
