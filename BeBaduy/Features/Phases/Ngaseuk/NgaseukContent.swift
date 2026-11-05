enum NgaseukContent {
    static let storyIntroduction = "Lahan siap ditanami. Dengan aseuk, sebuah tongkat tanam, lubang kecil dibuat untuk menempatkan benih padi."
    static let storyInstruction = "Ketuk tiga tanda pada tanah. Aseuk membuat lubang, lalu benih ditempatkan di dalamnya."
    static let storyMotionInstruction = "Ketuk untuk memilih sasaran. Gerakkan ponsel sedikit ke bawah, lalu kembali tenang."
    static let storySeedReminder = "Benih masih berada di dalam tanah. Pertumbuhan membutuhkan waktu."
    static let value = PhaseContent(id: .ngaseuk, title: "Ngaseuk", subtitle: "Menanam dengan aseuk",
        introduction: "Lahan siap ditanami. Kenali aseuk, tongkat untuk membuat lubang tanam.",
        instruction: "Ketuk tiga tanda untuk mengarahkan aseuk. Benih akan masuk setelah lubang dibuat. Gerakan ponsel tersedia sebagai pilihan.",
        explanation: "Aseuk membuat lubang tanpa membajak tanah. Benih ditempatkan ke lubang itu. Padi memerlukan waktu dan perawatan sebelum tumbuh dan siap dipanen.",
        result: "Tiga lubang berisi benih; padi belum tumbuh.", timeCue: nil, sourceIDs: ["S1", "S2"])
}
