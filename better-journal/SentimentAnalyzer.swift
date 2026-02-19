//
//  SentimentAnalyzer.swift
//  better-journal
//
//  Text modality emotion extractor.
//
//  Uses a 3-layer approach:
//    1. Emotion Lexicon: ~500 words mapped to emotion categories
//    2. NLTagger: Sentence-level valence as a distribution prior
//    3. Contextual modifiers: Negation + intensifier handling
//
//  Outputs ModalitySignal with EmotionDistribution.
//

import Foundation
import NaturalLanguage
import FoundationModels

struct SentimentAnalyzer {

    // MARK: - Emotion Lexicon

    /// Maps words/phrases to emotion category weights.
    /// Inspired by NRC EmoLex, tuned for journaling vocabulary.
    /// Each entry maps to one or more (Sentiment, weight) pairs.
    private static let lexicon: [String: [(Sentiment, Double)]] = {
        var lex: [String: [(Sentiment, Double)]] = [:]

        // Helper to add multiple words for an emotion
        func add(_ words: [String], _ mappings: [(Sentiment, Double)]) {
            for word in words { lex[word] = mappings }
        }

        // ── Happy ──
        add(["happy", "joy", "joyful", "wonderful", "amazing", "fantastic",
             "awesome", "great", "excellent", "brilliant", "delighted",
             "pleased", "thrilled", "elated", "cheerful", "merry",
             "blissful", "ecstatic", "overjoyed", "jubilant", "gleeful",
             "radiant", "sunny", "upbeat", "lighthearted", "beaming",
             "smiling", "smiled", "laughed", "laughing", "laughter",
             "fun", "funny", "hilarious", "celebrate", "celebrated",
             "good", "nice", "lovely", "beautiful", "perfect",
             "enjoy", "enjoyed", "enjoying", "enjoyable"],
            [(.happy, 0.85), (.excited, 0.3)])

        // ── Grateful ──
        add(["grateful", "thankful", "blessed", "appreciative", "appreciate",
             "appreciated", "gratitude", "fortunate", "lucky", "thanks",
             "thanking", "privilege", "privileged", "treasured", "valued",
             "cherish", "cherished", "honor", "honored"],
            [(.grateful, 0.9), (.happy, 0.35)])

        // ── Calm ──
        add(["calm", "peaceful", "serene", "tranquil", "relaxed",
             "relaxing", "gentle", "quiet", "still", "soothing",
             "comfortable", "content", "ease", "easygoing", "steady",
             "balanced", "centered", "grounded", "mindful", "meditate",
             "meditation", "breathing", "breathe", "zen", "harmony",
             "restful", "chill", "mellow", "collected"],
            [(.calm, 0.85), (.reflective, 0.2)])

        // ── Excited ──
        add(["excited", "exciting", "thrilling", "exhilarating", "energized",
             "pumped", "stoked", "fired", "eager", "enthusiastic",
             "passionate", "dynamic", "vibrant", "alive", "buzzing",
             "incredible", "unbelievable", "adrenaline", "rush",
             "adventure", "adventurous", "cannot wait", "looking forward"],
            [(.excited, 0.9), (.happy, 0.4)])

        // ── Hopeful ──
        add(["hopeful", "hope", "hoping", "optimistic", "optimism",
             "promising", "aspire", "aspiring", "dream", "dreaming",
             "envision", "believe", "faith", "trust", "trusting",
             "confident", "positive", "bright", "brighter", "improve",
             "improving", "progress", "forward", "better", "opportunity",
             "potential", "possible", "someday", "future", "plan", "goal"],
            [(.hopeful, 0.8), (.excited, 0.2)])

        // ── Reflective ──
        add(["reflect", "reflecting", "reflective", "thinking", "thought",
             "wonder", "wondering", "ponder", "pondering", "consider",
             "considering", "contemplate", "realize", "realized",
             "understand", "understood", "insight", "awareness",
             "perspective", "meaningful", "learn", "learned", "lesson",
             "growth", "growing", "journal", "journaling", "introspect",
             "process", "processing"],
            [(.reflective, 0.85), (.calm, 0.2)])

        // ── Nostalgic ──
        add(["nostalgic", "nostalgia", "remember", "remembering",
             "memories", "memory", "reminisce", "reminiscing",
             "childhood", "younger", "miss", "missing", "missed",
             "past", "ago", "those days", "back then", "used to",
             "wish I could", "hometown", "old friend", "reunion",
             "throwback", "tradition", "traditions", "heritage"],
            [(.nostalgic, 0.9), (.reflective, 0.3), (.sad, 0.15)])

        // ── Anxious ──
        add(["anxious", "anxiety", "nervous", "worried", "worry",
             "worrying", "uneasy", "restless", "tense", "tension",
             "dread", "dreading", "panic", "panicking", "panicked",
             "overthinking", "racing thoughts", "insomnia", "sleepless",
             "uncertain", "uncertainty", "doubt", "doubting",
             "apprehensive", "scared", "fear", "fearing", "afraid",
             "phobia", "paranoid", "overwhelmed", "spiraling",
             "what if", "nervous wreck", "on edge", "jittery"],
            [(.anxious, 0.9), (.stressed, 0.4)])

        // ── Sad ──
        add(["sad", "sadness", "unhappy", "depressed", "depression",
             "crying", "cried", "tears", "heartbroken", "heartbreak",
             "grief", "grieving", "mourning", "loss", "lost",
             "lonely", "loneliness", "alone", "isolated", "empty",
             "hollow", "hopeless", "despair", "despairing",
             "melancholy", "gloomy", "somber", "sorrow", "sorrowful",
             "blue", "feeling down", "devastated", "pain", "painful",
             "hurting", "suffering", "miserable", "discouraged",
             "disappointed", "disappointing", "letdown"],
            [(.sad, 0.9), (.nostalgic, 0.15)])

        // ── Frustrated ──
        add(["frustrated", "frustrating", "frustration", "angry", "anger",
             "furious", "rage", "raging", "annoyed", "annoying",
             "irritated", "irritating", "agitated", "mad", "livid",
             "infuriated", "pissed", "bothered", "hate", "hated",
             "hatred", "resentment", "resent", "bitter", "bitterness",
             "fed up", "sick of", "tired of", "can't stand",
             "unfair", "injustice", "wrong", "ridiculous", "absurd",
             "unacceptable", "outrageous", "snapped", "exploded"],
            [(.frustrated, 0.9), (.stressed, 0.3)])

        // ── Stressed ──
        add(["stressed", "stress", "stressful", "pressure", "pressured",
             "overwhelmed", "overwhelming", "burnout", "burned out",
             "exhausted", "exhausting", "drained", "fatigued",
             "overworked", "overloaded", "swamped", "slammed",
             "deadline", "deadlines", "behind", "falling behind",
             "too much", "drowning", "struggling", "struggle",
             "can't cope", "breaking point", "stretched thin",
             "demanding", "hectic", "chaotic", "chaos", "frantic"],
            [(.stressed, 0.9), (.anxious, 0.35)])

        // ── Neutral / Mixed ──
        add(["okay", "fine", "alright", "normal", "average",
             "regular", "usual", "typical", "routine", "ordinary",
             "so-so", "meh", "nothing special", "whatever",
             "same old", "uneventful", "mundane", "bland"],
            [(.neutral, 0.7)])

        return lex
    }()

    // MARK: - Negation Words

    private static let negators: Set<String> = [
        "not", "no", "never", "neither", "nobody", "nothing",
        "nowhere", "nor", "cannot", "can't", "couldn't",
        "didn't", "doesn't", "don't", "hadn't", "hasn't",
        "haven't", "isn't", "wasn't", "weren't", "won't",
        "wouldn't", "shouldn't", "barely", "hardly", "scarcely"
    ]

    // MARK: - Intensifiers

    private static let intensifiers: [String: Double] = [
        "very": 1.4, "really": 1.35, "extremely": 1.6,
        "incredibly": 1.5, "absolutely": 1.5, "utterly": 1.5,
        "deeply": 1.4, "terribly": 1.5, "awfully": 1.4,
        "so": 1.3, "super": 1.35, "quite": 1.15,
        "truly": 1.3, "immensely": 1.45, "remarkably": 1.35
    ]

    // MARK: - Negation Opposites (for flipping)

    private static let negationFlip: [Sentiment: Sentiment] = [
        .happy: .sad, .sad: .happy,
        .excited: .calm, .calm: .stressed,
        .grateful: .frustrated, .frustrated: .grateful,
        .hopeful: .anxious, .anxious: .hopeful,
    ]

    // MARK: - ModalitySignal Output

    /// Produce a calibration-ready ModalitySignal with EmotionDistribution.
    static func analyzeSignal(title: String, content: String) async -> ModalitySignal? {
        let text = (title + " " + content).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        let words = tokenize(text)
        let wordCount = words.count
        guard wordCount > 0 else { return nil }

        // ─── Step 1: Lexicon-based emotion detection ───

        var emotionAccum: [Sentiment: Double] = [:]
        var matchCount = 0

        var i = 0
        while i < words.count {
            let word = words[i]

            // Check for intensifier before emotion word
            var intensifier = 1.0
            var checkWord = word
            var skipNext = false

            if let mult = intensifiers[word], i + 1 < words.count {
                intensifier = mult
                checkWord = words[i + 1]
                skipNext = true
            }

            // Check for negation before emotion word
            var negated = false
            if negators.contains(word), i + 1 < words.count {
                negated = true
                checkWord = words[i + 1]
                skipNext = true
            }
            // Also check: "intensifier negator word" pattern
            if intensifiers[word] != nil, i + 2 < words.count, negators.contains(words[i + 1]) {
                intensifier = intensifiers[word]!
                negated = true
                checkWord = words[i + 2]
                i += 1 // skip extra
            }

            // Lookup in lexicon
            if let mappings = lexicon[checkWord] {
                matchCount += 1
                for (emotion, weight) in mappings {
                    let finalEmotion: Sentiment
                    if negated {
                        finalEmotion = negationFlip[emotion] ?? .neutral
                    } else {
                        finalEmotion = emotion
                    }
                    emotionAccum[finalEmotion, default: 0] += weight * intensifier
                }
                if skipNext { i += 1 }
            }

            i += 1
        }

        // ─── Step 2: NLTagger valence as distribution prior ───

        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text
        let range = text.startIndex..<text.endIndex

        var sentimentScores: [Double] = []
        tagger.enumerateTags(in: range, unit: .sentence, scheme: .sentimentScore) { tag, _ in
            if let tag, let score = Double(tag.rawValue) {
                sentimentScores.append(score)
            }
            return true
        }

        let taggerValence: Double = sentimentScores.isEmpty
            ? 0
            : sentimentScores.reduce(0, +) / Double(sentimentScores.count)

        // Convert NLTagger valence to a soft distribution prior
        let taggerDist = valenceToDistribution(taggerValence)

        // ─── Step 3: Combine lexicon + tagger ───

        var dist: EmotionDistribution

        if matchCount > 0 {
            // Build distribution from lexicon matches
            dist = EmotionDistribution.from(emotionAccum)

            // Blend with tagger prior (30% tagger, 70% lexicon)
            dist = dist.merged(with: taggerDist, weight: 0.43) // 0.43 * tagger ≈ 30% total
        } else {
            // No lexicon matches — rely entirely on tagger
            dist = taggerDist
        }

        // ─── Step 4: User feedback bias ───

        dist = MoodFeedbackStore.shared.biasDistribution(dist, forText: text)

        // ─── Step 5: Compute signal metadata ───

        let valence = dist.valence
        let arousal = dist.arousal

        // Confidence: based on lexicon coverage
        let coverageRatio = Double(matchCount) / max(1.0, Double(wordCount))
        let lexiconConfidence = min(0.85, coverageRatio * 4.0 + 0.15)  // scale up
        let confidence = matchCount > 0 ? lexiconConfidence : max(0.2, abs(taggerValence))

        // Uncertainty: decreases with word count
        let rawUncertainty = 1.0 / sqrt(Double(max(1, wordCount)))
        let uncertainty = max(0.12, min(0.55, rawUncertainty))

        // Arousal: boost from punctuation
        let exclamations = Double(text.filter { $0 == "!" }.count)
        let questions = Double(text.filter { $0 == "?" }.count)
        let caps = Double(text.filter(\.isUppercase).count)
        let totalChars = max(1.0, Double(text.count))
        let punctDensity = (exclamations + questions) / totalChars * 100
        let capsDensity = caps / totalChars
        let arousalBoost = min(0.3, punctDensity * 0.15 + capsDensity * 0.3)

        // Feature labels
        let topEmotions = dist.topK(3)
        var labels = topEmotions.map { "\($0.emotion.displayName.lowercased()) language" }
        var features = topEmotions.map { $0.probability }

        if matchCount > 0 {
            labels.append("\(matchCount) emotion words")
            features.append(Double(matchCount))
        }

        return ModalitySignal.make(
            modality: .text,
            valence: max(-1, min(1, valence)),
            arousal: min(1.0, max(0.1, arousal + arousalBoost)),
            confidence: confidence,
            uncertainty: uncertainty,
            emotionDistribution: dist,
            featureVector: features,
            featureLabels: labels
        )
    }

    // MARK: - Categorical (backward compat)

    /// Categorical sentiment — tries FoundationModels first, falls back to NLTagger.
    static func analyze(title: String, content: String) async -> Sentiment? {
        // Fast path: use the emotion distribution if we can
        if let signal = await analyzeSignal(title: title, content: content) {
            return signal.emotionDistribution.dominantEmotion
        }
        return .neutral
    }

    // MARK: - Insight Generation

    static func generateInsight(from entries: [JournalEntry]) async -> String? {
        guard SystemLanguageModel.default.availability == .available else {
            return nil
        }

        let summaries = entries.prefix(5).enumerated().map { index, entry in
            let sentiment = entry.sentiment?.displayName ?? "Unknown"
            let title = entry.title.isEmpty ? "Untitled" : entry.title
            let snippet = String(entry.content.prefix(200))
            return "Entry \(index + 1) (\(sentiment)): \"\(title)\" — \(snippet)"
        }

        let joined = summaries.joined(separator: "\n")
        let prompt = """
        You are a thoughtful journaling coach. Based on these recent journal entries, provide a single brief, \
        warm, and insightful observation (2 sentences max) about the person's emotional patterns or growth. \
        Be specific to what they wrote — don't be generic. Speak directly to them using "you".

        \(joined)
        """

        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            return response.content
        } catch {
            return nil
        }
    }

    // MARK: - Helpers

    /// Tokenize text to lowercase words
    private static func tokenize(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && $0.count > 1 }
    }

    /// Convert a valence score [-1, 1] to a soft emotion distribution
    private static func valenceToDistribution(_ valence: Double) -> EmotionDistribution {
        var probs = Array(repeating: 0.02, count: 12)

        if valence > 0.2 {
            // Positive: spread across happy, grateful, calm, excited, hopeful
            let strength = min(1.0, valence)
            probs[0] += strength * 0.3   // happy
            probs[1] += strength * 0.15  // grateful
            probs[2] += strength * 0.2   // calm
            probs[3] += strength * 0.15  // excited
            probs[4] += strength * 0.15  // hopeful
        } else if valence < -0.2 {
            // Negative: spread across anxious, sad, frustrated, stressed
            let strength = min(1.0, abs(valence))
            probs[7] += strength * 0.2   // anxious
            probs[8] += strength * 0.35  // sad
            probs[9] += strength * 0.2   // frustrated
            probs[10] += strength * 0.2  // stressed
        } else {
            // Neutral: reflective / neutral
            probs[5] += 0.2  // reflective
            probs[11] += 0.3 // neutral
        }

        return EmotionDistribution(probabilities: probs).normalized()
    }
}
