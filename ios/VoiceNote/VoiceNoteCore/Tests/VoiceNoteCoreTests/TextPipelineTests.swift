import XCTest
@testable import VoiceNoteCore

final class DictionaryTests: XCTestCase {
    func testReplacesAliasesWithTerm() {
        let entries = [DictionaryEntry(term: "Typeless", aliases: ["type less", "Type Less"])]
        let r = DictionaryProcessor.apply("我用 type less 寫筆記", entries: entries)
        XCTAssertEqual(r.text, "我用 Typeless 寫筆記")
        XCTAssertEqual(r.changes.count, 1)
        XCTAssertEqual(r.changes.first?.kind, .dictionary)
    }

    func testLongerAliasWins() {
        let entries = [DictionaryEntry(term: "台北101", aliases: ["台北一零一", "一零一"])]
        XCTAssertEqual(DictionaryProcessor.apply("去台北一零一", entries: entries).text, "去台北101")
    }

    func testContextualStrings() {
        let entries = [DictionaryEntry(term: "Claude", aliases: ["克勞德"]), DictionaryEntry(term: "Claude")]
        XCTAssertEqual(DictionaryProcessor.contextualStrings(from: entries), ["Claude"])
    }
}

final class CorrectionTests: XCTestCase {
    func testChangeTimeWithBareGai() {
        XCTAssertEqual(CorrectionProcessor.apply("下午2點開會，改3點").text, "下午3點開會")
    }

    func testChangeTimeKeepsFollowingText() {
        XCTAssertEqual(CorrectionProcessor.apply("下午2點開會，改成3點，記得帶資料。").text, "下午3點開會，記得帶資料。")
    }

    func testChineseNumerals() {
        XCTAssertEqual(CorrectionProcessor.apply("明天早上八點集合，不對，九點。").text, "明天早上九點集合。")
    }

    func testBuDuiWithSimilarWord() {
        XCTAssertEqual(CorrectionProcessor.apply("星期三要交報告，不對，星期四").text, "星期四要交報告")
    }

    func testQuantityAndNoun() {
        XCTAssertEqual(CorrectionProcessor.apply("幫我買三個蘋果，不對，五個香蕉").text, "幫我買五個香蕉")
    }

    func testBuShiShiForm() {
        XCTAssertEqual(CorrectionProcessor.apply("約在二樓，不是，是三樓").text, "約在三樓")
    }

    func testNoTargetLeavesTextUntouched() {
        let input = "我今天很開心，不對，很難過"
        XCTAssertEqual(CorrectionProcessor.apply(input).text, input)
    }

    func testDoesNotTouchNormalSentences() {
        for s in ["明天，應該是晴天", "把顏色改成紅色", "我很累，不是很想去", "這份文件要修改3次"] {
            XCTAssertEqual(CorrectionProcessor.apply(s).text, s, s)
        }
    }

    func testOnlyLooksWithinParagraph() {
        let input = "早上十點開會。\n下午去買東西，改十一點"
        XCTAssertEqual(CorrectionProcessor.apply(input).text, input)
    }

    func testRecordsChange() {
        let r = CorrectionProcessor.apply("下午2點，改3點")
        XCTAssertEqual(r.changes.first?.from, "2點")
        XCTAssertEqual(r.changes.first?.to, "3點")
    }
}

final class ListCommandTests: XCTestCase {
    func testThreePointsSplitBySentence() {
        let input = "今天開會記下這三點。要買牛奶。要繳電費。要打電話給媽媽。"
        let expected = "今天開會記下這三點：\n1. 要買牛奶\n2. 要繳電費\n3. 要打電話給媽媽"
        XCTAssertEqual(TextPipeline.process(input).text, expected)
    }

    func testThreePointsWithOrdinals() {
        let input = "記下這三點，第一買牛奶，第二繳電費，第三打電話給媽媽，以上，然後明天要早起。"
        let out = TextPipeline.process(input).text
        XCTAssertEqual(out, "記下這三點：\n1. 買牛奶\n2. 繳電費\n3. 打電話給媽媽\n然後明天要早起。")
    }

    func testThreePointsSplitByComma() {
        let input = "幫我記下這三點，買牛奶，繳電費，打電話給媽媽"
        XCTAssertEqual(TextPipeline.process(input).text, "幫我記下這三點：\n1. 買牛奶\n2. 繳電費\n3. 打電話給媽媽")
    }

    func testTrailingSentencesStayOutsideList() {
        let input = "記下這兩點。買牛奶。繳電費。然後明天要早起。"
        XCTAssertEqual(TextPipeline.process(input).text, "記下這兩點：\n1. 買牛奶\n2. 繳電費\n\n然後明天要早起。")
    }

    func testUnknownCountUsesSentences() {
        let input = "以下幾點。買牛奶。繳電費。就這樣"
        XCTAssertEqual(TextPipeline.process(input).text, "以下幾點：\n1. 買牛奶\n2. 繳電費")
    }

    func testTimeIsNotMistakenForList() {
        let input = "記下三點開會這件事"
        XCTAssertEqual(TextPipeline.process(input).text, input)
    }

    func testUnsplittableStaysAsIs() {
        let input = "記下這三點，就是要努力"
        XCTAssertEqual(TextPipeline.process(input).text, input)
    }
}

final class CommandTests: XCTestCase {
    func testNewlineAndParagraph() {
        let input = "今天很累，換行，明天要早起，新段落，後天放假"
        XCTAssertEqual(TextPipeline.process(input).text, "今天很累\n明天要早起\n\n後天放假")
    }

    func testSpokenPunctuation() {
        XCTAssertEqual(TextPipeline.process("今天很累 句號 明天再說 問號").text, "今天很累。明天再說？")
    }

    func testFillersOffByDefault() {
        let input = "嗯，今天很累"
        XCTAssertEqual(TextPipeline.process(input).text, input)
        XCTAssertEqual(TextPipeline.process(input, options: ProcessingOptions(removeFillers: true)).text, "今天很累")
    }

    func testRawInputIsNeverMutated() {
        let raw = "下午2點，改3點"
        _ = TextPipeline.process(raw)
        XCTAssertEqual(raw, "下午2點，改3點")
    }

    func testCombined() {
        let dict = [DictionaryEntry(term: "Claude", aliases: ["克勞德"])]
        let input = "跟克勞德討論記下這兩點，下午2點開會改3點，第二，要準備簡報，以上"
        let out = TextPipeline.process(input, dictionary: dict).text
        XCTAssertEqual(out, "跟Claude討論記下這兩點：\n1. 下午3點開會\n2. 要準備簡報")
    }
}

final class ChineseNumberTests: XCTestCase {
    func testParse() {
        XCTAssertEqual(ChineseNumber.parse("三"), 3)
        XCTAssertEqual(ChineseNumber.parse("兩"), 2)
        XCTAssertEqual(ChineseNumber.parse("十"), 10)
        XCTAssertEqual(ChineseNumber.parse("十一"), 11)
        XCTAssertEqual(ChineseNumber.parse("二十三"), 23)
        XCTAssertEqual(ChineseNumber.parse("3"), 3)
        XCTAssertEqual(ChineseNumber.parse("３"), 3)
        XCTAssertNil(ChineseNumber.parse("幾"))
    }
}
