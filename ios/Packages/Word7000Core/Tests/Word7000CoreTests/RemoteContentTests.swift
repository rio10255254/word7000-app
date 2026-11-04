import XCTest
@testable import Word7000Core

final class RemoteContentTests: XCTestCase {
    private let adapt = WordEntry(id: "w0001", word: "adapt", partOfSpeech: "v", pronunciation: "", meaningZh: "適應",
                                  supplementalMeaningZh: "調整", example: "We adapt.", exampleZh: "我們適應。", group: "Core 1")
    private let bad = WordEntry(id: "w0002", word: "oops", partOfSpeech: "n", pronunciation: "", meaningZh: "錯字",
                                example: "", exampleZh: "", group: "Core 1")

    func testCorrectionsChangeOnlyTheGivenFieldsAndCanHideAWord() {
        let content = RemoteContent(corrections: [
            WordCorrection(mode: "english", wordId: "w0001", fields: ["meaningZh": " 適應；適合 ", "supplementalMeaningZh": "", "nonsense": "x"]),
            WordCorrection(mode: "english", wordId: "w0002", hidden: true),
            WordCorrection(mode: "chinese", wordId: "w0001", fields: ["meaningZh": "不該套用"]),
        ])
        let fixed = content.corrected([adapt, bad], mode: "english")
        XCTAssertEqual(fixed.map(\.id), ["w0001"])
        XCTAssertEqual(fixed[0].meaningZh, "適應；適合")
        XCTAssertNil(fixed[0].supplementalMeaningZh)
        XCTAssertEqual(fixed[0].example, "We adapt.")
        XCTAssertEqual(content.corrected([adapt], mode: "chinese")[0].meaningZh, "不該套用")
    }

    func testOfficialBanksDecodeSafelyAndSortByMode() throws {
        let json = """
        [{"id":"medical","mode":"english","name_zh":"醫護英文","sort":2,"updated_at":"t1","words":[
           {"id":"pack-medical-symptom","word":"symptom","partOfSpeech":"n","pronunciation":"","meaningZh":"症狀","example":"","exampleZh":"","group":"Level 1"},
           {"id":"w0001","word":"adapt","partOfSpeech":"v","pronunciation":"","meaningZh":"適應","example":"","exampleZh":"","group":"Core 1"},
           {"id":"pack-medical-broken"},
           {"id":"pack-medical-symptom","word":"again","partOfSpeech":"n","pronunciation":"","meaningZh":"重複","example":"","exampleZh":"","group":"Level 1"}]},
         {"id":"business","mode":"english","name_zh":"商用英文","sort":1,"updated_at":"t1","premium":true,"words":[
           {"id":"pack-business-invoice","word":"invoice","partOfSpeech":"n","pronunciation":"","meaningZh":"發票","example":"","exampleZh":"","group":"Level 1"}]},
         {"id":"empty","mode":"english","name_zh":"空的","words":[]},
         {"id":"daily","mode":"chinese","name_zh":"生活華語","words":[]}]
        """
        let banks = try JSONDecoder().decode([OfficialBank].self, from: Data(json.utf8))
        XCTAssertEqual(banks[0].words.map(\.word), ["symptom"], "Only valid words with pack- ids, each once")
        let content = RemoteContent(corrections: [WordCorrection(mode: "english", wordId: "pack-business-invoice", fields: ["meaningZh": "請款單"])],
                                    banks: banks)
        let english = content.banks(for: "english")
        XCTAssertEqual(english.map(\.id), ["business", "medical"])
        XCTAssertTrue(english[0].premium)
        XCTAssertEqual(english[0].words[0].meaningZh, "請款單")
        XCTAssertEqual(english[0].selectionId, "official:business")
        XCTAssertTrue(content.banks(for: "chinese").isEmpty)
        XCTAssertEqual(try JSONDecoder().decode(RemoteContent.self, from: JSONEncoder().encode(content)), content)
    }
}
