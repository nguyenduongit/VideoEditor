import Foundation

extension StickerPreset {
    /// Hàm tạo mã Vector SVG chuẩn W3C 500x500 chứa ký tự Apple Color Emoji căn giữa tuyệt đối.
    public static func makeEmojiSVG(_ emoji: String) -> String {
        """
        <svg viewBox="0 0 500 500" xmlns="http://www.w3.org/2000/svg">
          <text x="250" y="378" font-size="340" text-anchor="middle" font-family="Apple Color Emoji">\(emoji)</text>
        </svg>
        """
    }

    private struct EmojiDefinition {
        let id: String
        let name: String
        let emoji: String
        let desc: String
        let tags: [String]
    }

    private static let rawEmojiDefinitions: [EmojiDefinition] = [
        EmojiDefinition(id: "sticker_emoji_grinning", name: "Cười tươi", emoji: "😀", desc: "Nụ cười rạng rỡ, phấn khởi", tags: ["smile", "happy", "grinning", "cuoi", "vui"]),
        EmojiDefinition(id: "sticker_emoji_smiling_big_eyes", name: "Cười hớn hở", emoji: "😃", desc: "Mắt mở to vui vẻ", tags: ["smile", "big eyes", "hon ho", "vui"]),
        EmojiDefinition(id: "sticker_emoji_smiling_eyes", name: "Cười tít mắt", emoji: "😄", desc: "Cười híp mắt thân thiện", tags: ["smile", "tit mat", "happy", "cuoi"]),
        EmojiDefinition(id: "sticker_emoji_beaming", name: "Cười toe toét", emoji: "😁", desc: "Cười khoe răng tươi rói", tags: ["grin", "beaming", "rang", "cuoi toe toet"]),
        EmojiDefinition(id: "sticker_emoji_squinting", name: "Cười sảng khoái", emoji: "😆", desc: "Cười nhắm tịt mắt thích thú", tags: ["laugh", "sang khoai", "lol", "haha"]),
        EmojiDefinition(id: "sticker_emoji_sweat_smile", name: "Cười trừ toát mồ hôi", emoji: "😅", desc: "Cười ngượng ngùng, nhẹ nhõm", tags: ["sweat", "mo hoi", "ngai", "cuoi tru"]),
        EmojiDefinition(id: "sticker_emoji_tears_of_joy", name: "Cười ra nước mắt", emoji: "😂", desc: "Hài hước đỉnh điểm", tags: ["joy", "tears", "ra nuoc mat", "haha", "hai huoc"]),
        EmojiDefinition(id: "sticker_emoji_rofl", name: "Cười lăn lộn", emoji: "🤣", desc: "Nghiêng ngả vì buồn cười", tags: ["rofl", "lan lon", "cuoi bo", "lol"]),
        EmojiDefinition(id: "sticker_emoji_warm_smile", name: "Cười đằm thắm", emoji: "😊", desc: "Nụ cười ấm áp, má ửng hồng", tags: ["warm", "smile", "dam tham", "ma hong", "de thuong"]),
        EmojiDefinition(id: "sticker_emoji_halo", name: "Thiên thần thánh thiện", emoji: "😇", desc: "Vô số tội, hiền lành có hào quang", tags: ["halo", "angel", "thien than", "thanh thien"]),
        EmojiDefinition(id: "sticker_emoji_slight_smile", name: "Cười mỉm", emoji: "🙂", desc: "Nụ cười nhẹ nhàng, tích cực", tags: ["slight", "smile", "cuoi mim", "nhe nhang"]),
        EmojiDefinition(id: "sticker_emoji_upside_down", name: "Cười lộn ngược", emoji: "🙃", desc: "Châm biếm, ngớ ngẩn hài hước", tags: ["upside down", "lon nguoc", "cham biem"]),
        EmojiDefinition(id: "sticker_emoji_wink", name: "Nháy mắt", emoji: "😉", desc: "Tinh nghịch, ra hiệu đồng tình", tags: ["wink", "nhay mat", "tinh nghich"]),
        EmojiDefinition(id: "sticker_emoji_heart_eyes", name: "Mắt trái tim", emoji: "😍", desc: "Say đắm, cực kỳ yêu thích", tags: ["heart eyes", "mat tim", "yeu", "love", "thich"]),
        EmojiDefinition(id: "sticker_emoji_hearts", name: "Hạnh phúc ngập tràn", emoji: "🥰", desc: "Ba trái tim bay quanh má hồng", tags: ["hearts", "yeu thuong", "hanh phuc", "love"]),
        EmojiDefinition(id: "sticker_emoji_kiss", name: "Hôn gió", emoji: "😘", desc: "Gửi nụ hôn kèm trái tim", tags: ["kiss", "hon gio", "trai tim", "love"]),
        EmojiDefinition(id: "sticker_emoji_yum", name: "Thè lưỡi thèm ăn", emoji: "😋", desc: "Món ngon hấp dẫn, tinh nghịch", tags: ["yum", "the luoi", "ngon", "them"]),
        EmojiDefinition(id: "sticker_emoji_wink_tongue", name: "Nháy mắt thè lưỡi", emoji: "😜", desc: "Trêu chọc, đùa vui", tags: ["wink", "tongue", "treu", "nghich"]),
        EmojiDefinition(id: "sticker_emoji_zany", name: "Mặt ngố lác mắt", emoji: "🤪", desc: "Phát cuồng, nghịch ngợm hết nấc", tags: ["zany", "ngo", "dien", "dien ro"]),
        EmojiDefinition(id: "sticker_emoji_cool", name: "Kính râm cực ngầu", emoji: "😎", desc: "Tự tin, phong cách sành điệu", tags: ["cool", "kinh ram", "ngau", "sunglasses", "pro"]),
        EmojiDefinition(id: "sticker_emoji_nerd", name: "Mọt sách thông thái", emoji: "🤓", desc: "Kính cận răng thỏ, chăm chú", tags: ["nerd", "mot sach", "kinh can", "thong thai"]),
        EmojiDefinition(id: "sticker_emoji_monocle", name: "Soi kính lúp", emoji: "🧐", desc: "Quan sát kỹ lưỡng, tò mò", tags: ["monocle", "kinh lup", "soi", "to mo"]),
        EmojiDefinition(id: "sticker_emoji_thinking", name: "Suy nghĩ trầm ngâm", emoji: "🤔", desc: "Đắn đo, tự hỏi, cân nhắc", tags: ["thinking", "suy nghi", "phan van", "hoi"]),
        EmojiDefinition(id: "sticker_emoji_shushing", name: "Suỵt giữ bí mật", emoji: "🤫", desc: "Ngón tay đặt lên môi im lặng", tags: ["shush", "suyt", "im lang", "bi mat"]),
        EmojiDefinition(id: "sticker_emoji_hand_mouth", name: "Che miệng cười duyên", emoji: "🤭", desc: "Ngạc nhiên hoặc khúc khích cười", tags: ["hand over mouth", "che mieng", "ngai", "cuoi duyen"]),
        EmojiDefinition(id: "sticker_emoji_zipper", name: "Kéo khóa miệng", emoji: "🤐", desc: "Giữ kín miệng, không nói nửa lời", tags: ["zipper", "khoa mieng", "im lang", "kin mieng"]),
        EmojiDefinition(id: "sticker_emoji_raised_eyebrow", name: "Nhướn mày nghi ngờ", emoji: "🤨", desc: "Hoài nghi, đánh giá", tags: ["raised eyebrow", "nhuon may", "nghi ngo"]),
        EmojiDefinition(id: "sticker_emoji_neutral", name: "Mặt đơ vô cảm", emoji: "😐", desc: "Cạn lời, bình thản", tags: ["neutral", "vo cam", "can loi", "mat do"]),
        EmojiDefinition(id: "sticker_emoji_expressionless", name: "Bất lực nhắm mắt", emoji: "😑", desc: "Không còn gì để nói", tags: ["expressionless", "bat luc", "khong con gi de noi"]),
        EmojiDefinition(id: "sticker_emoji_sleeping", name: "Buồn ngủ say giấc", emoji: "😴", desc: "Kèm biểu tượng Zzz", tags: ["sleeping", "ngu", "buon ngu", "zzz"]),
        EmojiDefinition(id: "sticker_emoji_drooling", name: "Thèm thuồng chảy dãi", emoji: "🤤", desc: "Quá mê mẩn hoặc say sưa", tags: ["drooling", "chay dai", "them thuong", "me man"]),
        EmojiDefinition(id: "sticker_emoji_loudly_crying", name: "Khóc ròng tuôn lệ", emoji: "😭", desc: "Đau lòng hoặc xúc động mạnh", tags: ["crying", "khoc rong", "suoi le", "buon", "dau long"]),
        EmojiDefinition(id: "sticker_emoji_screaming", name: "La hét hoảng hốt", emoji: "😱", desc: "Ôm má kinh ngạc kiểu Munch", tags: ["scream", "la het", "hoang hot", "kinh ngac", "so hai"]),
        EmojiDefinition(id: "sticker_emoji_enraged", name: "Bốc hỏa nổi giận", emoji: "😡", desc: "Mặt đỏ phẫn nộ, tức tối", tags: ["rage", "enraged", "tuc gian", "boc hoa", "noi gian"]),
        EmojiDefinition(id: "sticker_emoji_clown", name: "Chú hề", emoji: "🤡", desc: "Tấu hài, ngớ ngẩn", tags: ["clown", "chu he", "tau hai", "ngo ngan"]),
        EmojiDefinition(id: "sticker_emoji_ghost", name: "Hồn ma tinh nghịch", emoji: "👻", desc: "Thè lưỡi dọa ma hài hước", tags: ["ghost", "hon ma", "halloween", "doa ma"])
    ]

    /// Danh mục 36 mẫu Nhãn dán Emoji tuyển chọn, đạt chuẩn Vector SVG 500x500 hiển thị sắc nét bằng font Apple Color Emoji.
    public static let emojiPresets: [StickerPreset] = rawEmojiDefinitions.map { def in
        let svg = makeEmojiSVG(def.emoji)
        return StickerPreset(
            id: def.id,
            name: "\(def.name) \(def.emoji)",
            description: def.desc,
            category: .emoji,
            format: .svg,
            tags: def.tags + ["emoji", def.emoji],
            defaultDuration: 3.0,
            systemSymbolFallback: "face.smiling",
            config: StickerConfiguration(
                format: .svg,
                loopMode: .loop,
                playbackSpeed: 1.0,
                sourceURLString: nil,
                svgMarkup: svg,
                systemSymbolFallback: "face.smiling",
                hasShadow: false,
                shadowColorHex: "#00000040",
                shadowBlur: 8.0,
                shadowDistance: 3.0
            ),
            isSystem: true
        )
    }
}

