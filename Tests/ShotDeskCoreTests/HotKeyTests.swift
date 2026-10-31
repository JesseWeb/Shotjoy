import XCTest
@testable import ShotDeskCore

final class HotKeyTests: XCTestCase {
    func testDefaultMatchesWeChat() {
        let hotKey = HotKeyConfig.default
        XCTAssertEqual(hotKey.keyCode, 0)
        XCTAssertEqual(hotKey.modifiers, [.control, .command])
        XCTAssertEqual(hotKey.displayString, "⌃⌘A")
        XCTAssertTrue(hotKey.isUsable)
    }

    func testShortcutNeedsModifiers() {
        let bare = HotKeyConfig(keyCode: 0, modifiers: [])
        XCTAssertFalse(bare.isUsable)
    }

    func testModifierOnlyKeyIsNotUsable() {
        let modifier = HotKeyConfig(keyCode: 55, modifiers: [.command])
        XCTAssertFalse(modifier.isUsable)
    }

    func testKeyNames() {
        XCTAssertEqual(HotKeyConfig.keyName(for: 0), "A")
        XCTAssertEqual(HotKeyConfig.keyName(for: 36), "Return")
        XCTAssertEqual(HotKeyConfig.keyName(for: 49), "Space")
        XCTAssertEqual(HotKeyConfig.keyName(for: 123), "←")
    }

    func testModifierOrderMatchesMacConvention() {
        let modifiers: ShortcutModifiers = [.command, .shift, .option, .control]
        XCTAssertEqual(modifiers.displayString, "⌃⌥⇧⌘")
    }
}
