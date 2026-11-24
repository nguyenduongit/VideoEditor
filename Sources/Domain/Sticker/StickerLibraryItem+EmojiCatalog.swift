import Foundation

extension StickerLibraryItem {
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
        EmojiDefinition(id: "sticker_emoji_grinning", name: "Grinning", emoji: "😀", desc: "Bright, cheerful smile", tags: ["smile", "happy", "grinning"]),
        EmojiDefinition(id: "sticker_emoji_smiling_big_eyes", name: "Big Smile", emoji: "😃", desc: "Open eyes with happy grin", tags: ["smile", "big eyes", "happy"]),
        EmojiDefinition(id: "sticker_emoji_smiling_eyes", name: "Happy Eyes", emoji: "😄", desc: "Friendly squinting smile", tags: ["smile", "happy", "friendly"]),
        EmojiDefinition(id: "sticker_emoji_beaming", name: "Beaming", emoji: "😁", desc: "Toothy radiant grin", tags: ["grin", "beaming", "smile"]),
        EmojiDefinition(id: "sticker_emoji_squinting", name: "Laughing", emoji: "😆", desc: "Tightly closed eyes laughing", tags: ["laugh", "lol", "haha"]),
        EmojiDefinition(id: "sticker_emoji_sweat_smile", name: "Relieved Sweat", emoji: "😅", desc: "Nervous or relieved chuckle", tags: ["sweat", "nervous", "relief"]),
        EmojiDefinition(id: "sticker_emoji_tears_of_joy", name: "Tears of Joy", emoji: "😂", desc: "Peak comedic laughter", tags: ["joy", "tears", "haha", "funny"]),
        EmojiDefinition(id: "sticker_emoji_rofl", name: "ROFL", emoji: "🤣", desc: "Rolling on the floor laughing", tags: ["rofl", "funny", "lol"]),
        EmojiDefinition(id: "sticker_emoji_warm_smile", name: "Blushing Smile", emoji: "😊", desc: "Warm smile with rosy cheeks", tags: ["warm", "smile", "blush", "cute"]),
        EmojiDefinition(id: "sticker_emoji_halo", name: "Innocent Halo", emoji: "😇", desc: "Angelic smile with glowing halo", tags: ["halo", "angel", "innocent"]),
        EmojiDefinition(id: "sticker_emoji_slight_smile", name: "Gentle Smile", emoji: "🙂", desc: "Subtle, positive smile", tags: ["slight", "smile", "gentle"]),
        EmojiDefinition(id: "sticker_emoji_upside_down", name: "Upside Down", emoji: "🙃", desc: "Sarcastic or playful humor", tags: ["upside down", "sarcasm", "silly"]),
        EmojiDefinition(id: "sticker_emoji_wink", name: "Wink", emoji: "😉", desc: "Playful wink and nod", tags: ["wink", "playful"]),
        EmojiDefinition(id: "sticker_emoji_heart_eyes", name: "Heart Eyes", emoji: "😍", desc: "Infatuated, starry-eyed love", tags: ["heart eyes", "love", "adore"]),
        EmojiDefinition(id: "sticker_emoji_hearts", name: "In Love", emoji: "🥰", desc: "Floating hearts and warm blush", tags: ["hearts", "love", "warm"]),
        EmojiDefinition(id: "sticker_emoji_kiss", name: "Blowing Kiss", emoji: "😘", desc: "Sending a kiss with a heart", tags: ["kiss", "heart", "love"]),
        EmojiDefinition(id: "sticker_emoji_yum", name: "Yummy", emoji: "😋", desc: "Savoring something delicious", tags: ["yum", "delicious", "playful"]),
        EmojiDefinition(id: "sticker_emoji_wink_tongue", name: "Wink Tongue", emoji: "😜", desc: "Teasing and playful fun", tags: ["wink", "tongue", "tease", "fun"]),
        EmojiDefinition(id: "sticker_emoji_zany", name: "Zany Face", emoji: "🤪", desc: "Goofy, wild excitement", tags: ["zany", "goofy", "crazy"]),
        EmojiDefinition(id: "sticker_emoji_cool", name: "Cool Shades", emoji: "😎", desc: "Confident sunglasses style", tags: ["cool", "sunglasses", "pro"]),
        EmojiDefinition(id: "sticker_emoji_nerd", name: "Nerd", emoji: "🤓", desc: "Focused glasses and smart vibe", tags: ["nerd", "glasses", "smart"]),
        EmojiDefinition(id: "sticker_emoji_monocle", name: "Monocle", emoji: "🧐", desc: "Curious and observant look", tags: ["monocle", "curious", "inspect"]),
        EmojiDefinition(id: "sticker_emoji_thinking", name: "Thinking", emoji: "🤔", desc: "Pondering and weighing options", tags: ["thinking", "wonder", "question"]),
        EmojiDefinition(id: "sticker_emoji_shushing", name: "Shushing", emoji: "🤫", desc: "Finger over lips keeping a secret", tags: ["shush", "quiet", "secret"]),
        EmojiDefinition(id: "sticker_emoji_hand_mouth", name: "Giggle", emoji: "🤭", desc: "Surprised chuckle behind hand", tags: ["hand over mouth", "shy", "giggle"]),
        EmojiDefinition(id: "sticker_emoji_zipper", name: "Zipper Mouth", emoji: "🤐", desc: "Lips sealed, saying nothing", tags: ["zipper", "quiet", "secret"]),
        EmojiDefinition(id: "sticker_emoji_raised_eyebrow", name: "Skeptical", emoji: "🤨", desc: "Doubtful raised eyebrow", tags: ["raised eyebrow", "skeptical", "doubt"]),
        EmojiDefinition(id: "sticker_emoji_neutral", name: "Deadpan", emoji: "😐", desc: "Speechless neutral expression", tags: ["neutral", "deadpan", "calm"]),
        EmojiDefinition(id: "sticker_emoji_expressionless", name: "Done With It", emoji: "😑", desc: "Unimpressed closed-eye stare", tags: ["expressionless", "unimpressed"]),
        EmojiDefinition(id: "sticker_emoji_sleeping", name: "Sleepy", emoji: "😴", desc: "Fast asleep with Zzz icon", tags: ["sleeping", "sleep", "zzz"]),
        EmojiDefinition(id: "sticker_emoji_drooling", name: "Drooling", emoji: "🤤", desc: "Obsessed or mouth-watering", tags: ["drooling", "craving", "obsessed"]),
        EmojiDefinition(id: "sticker_emoji_loudly_crying", name: "Loudly Crying", emoji: "😭", desc: "Heartbroken or overwhelmed with emotion", tags: ["crying", "sobbing", "sad"]),
        EmojiDefinition(id: "sticker_emoji_screaming", name: "Shocked Scream", emoji: "😱", desc: "Hands-on-cheeks astonishment", tags: ["scream", "shock", "scared"]),
        EmojiDefinition(id: "sticker_emoji_enraged", name: "Enraged", emoji: "😡", desc: "Red-faced furious anger", tags: ["rage", "enraged", "angry"]),
        EmojiDefinition(id: "sticker_emoji_clown", name: "Clown", emoji: "🤡", desc: "Comedic and silly clowning around", tags: ["clown", "funny", "silly"]),
        EmojiDefinition(id: "sticker_emoji_ghost", name: "Playful Ghost", emoji: "👻", desc: "Cheeky tongue-out spooky fun", tags: ["ghost", "halloween", "spooky"])
    ]

    /// Danh mục 36 mẫu Nhãn dán Emoji tuyển chọn, đạt chuẩn Vector SVG 500x500 hiển thị sắc nét bằng font Apple Color Emoji.
    public static let emojiItems: [StickerLibraryItem] = rawEmojiDefinitions.map { def in
        let svg = makeEmojiSVG(def.emoji)
        return StickerLibraryItem(
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
            )
        )
    }
}

