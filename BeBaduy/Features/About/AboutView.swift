import SwiftUI
struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Belajar dengan rasa ingin tahu").font(.largeTitle.bold())
                Text("BeBaduy adalah prototipe pengantar. Lima bab merupakan susunan belajar aplikasi, bukan klasifikasi budaya yang berlaku untuk semua komunitas. Istilah dan praktik dapat berbeda antarcatatan dan komunitas.")
                Text("Ilustrasi, jumlah sasaran, dan posisi penempatan disederhanakan untuk interaksi. Aplikasi tidak meminta pengguna melakukan ritual. Nama, gambar, dan penjelasan masih memerlukan tinjauan bersama kolaborator Baduy sebelum rilis publik.")
                Text("Gambar suasana dibuat dengan bantuan AI sebagai ilustrasi pembelajaran, bukan foto dokumentasi kehidupan masyarakat Baduy.")
                Text("Semua materi belajar dan progres tersedia luring. Progres disimpan hanya di perangkat ini; demonstrasi dan praktik sama-sama membuka penjelasan.")
            }.padding(24).frame(maxWidth: 640, alignment: .leading).frame(maxWidth: .infinity)
        }.background(AppTheme.background).navigationTitle("Tentang BeBaduy").navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}
