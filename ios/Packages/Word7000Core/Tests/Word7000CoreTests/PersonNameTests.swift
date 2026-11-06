import XCTest
@testable import Word7000Core

final class PersonNameTests: XCTestCase {
    func testChineseNamesPutTheFamilyNameFirstWithoutASpace() {
        XCTAssertEqual(PersonName.compose(given: "彥誼", family: "江"), "江彥誼")
        XCTAssertEqual(PersonName.compose(given: "Ava", family: "Chen"), "Ava Chen")
        XCTAssertEqual(PersonName.compose(given: " 彥誼 ", family: nil), "彥誼")
        XCTAssertNil(PersonName.compose(given: "", family: nil))
    }

    func testAStoredNameInTheWrongOrderReadsRightFromItsParts() {
        let user = AuthUser(id: "u", isAnonymous: false,
                            userMetadata: ["full_name": .string("彥誼 江"), "given_name": .string("彥誼"), "family_name": .string("江")])
        XCTAssertEqual(user.displayName, "江彥誼")
    }
}
