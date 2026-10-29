import XCTest

/// Drives the main flows in demo mode (a fresh temp copy of the sample notes).
final class OrganizedStickiesUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-demo"]
        app.launch()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
    }

    override func tearDown() { app.terminate() }

    private func note(_ title: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "note-\(title)").firstMatch
    }

    private func folder(_ name: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "folder-\(name)").firstMatch
    }

    func testWriteANoteAndItStays() {
        app.buttons["newNoteButton"].click()
        let editor = app.textViews["noteEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.typeText("Racket restring\n58 lbs, poly")
        editor.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(note("Racket restring").waitForExistence(timeout: 5))
        // Switch away and back: still there.
        folder("Cooking").click()
        folder("Inbox").click()
        XCTAssertTrue(note("Racket restring").waitForExistence(timeout: 5))
    }

    func testSuggestionsMoveNotesOutOfInbox() {
        let moveAll = app.buttons["moveAllSuggested"]
        XCTAssertTrue(moveAll.waitForExistence(timeout: 20), "sample Inbox should get suggestions")
        XCTAssertTrue(note("Q3/Q4: plan").exists)
        moveAll.click()
        // Moving notes gives folders more evidence, so a few new suggestions may
        // appear afterwards; that's expected. A note the sorter files under Robot Learning is now there.
        XCTAssertTrue(note("Q3/Q4: plan").waitForNonExistence(timeout: 5))
        folder("Robot Learning").click()
        XCTAssertTrue(note("Q3/Q4: plan").waitForExistence(timeout: 5))
    }

    func testCreateAndRenameFolder() {
        app.buttons["newFolderButton"].click()
        let field = app.textFields["folderNameField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeKey("a", modifierFlags: .command)
        field.typeText("Tennis\n")
        XCTAssertTrue(folder("Tennis").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Nothing in Tennis yet"].waitForExistence(timeout: 5))
    }

    func testSearchFindsAcrossFolders() {
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.click()
        search.typeText("Neuropixels")
        XCTAssertTrue(app.staticTexts["Search"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'note-'")).firstMatch.waitForExistence(timeout: 5))
        search.typeText("zzzqqq")
        XCTAssertTrue(app.staticTexts["No notes match"].waitForExistence(timeout: 5))
    }

    func testKeyboardSelectAndMove() {
        folder("Cooking").click()
        XCTAssertTrue(note("Miso cod").waitForExistence(timeout: 5))
        // Picking a folder puts the keyboard on its notes: → selects the first card.
        app.typeKey(.rightArrow, modifierFlags: [])
        // ⌥⌘1 = Note › Move To › Inbox.
        app.typeKey("1", modifierFlags: [.command, .option])
        XCTAssertTrue(note("Miso cod").waitForNonExistence(timeout: 5))
        folder("Inbox").click()
        XCTAssertTrue(note("Miso cod").waitForExistence(timeout: 5))
    }

    /// A first import with no folders: the Inbox offers groups, and one click
    /// makes a folder with the name you gave it and moves its notes in.
    func testStarterFolderMakesAFolderWithItsNotes() {
        app.terminate()
        app.launchArguments = ["-demo", "-unsorted"]
        app.launch()
        let make = app.buttons.matching(identifier: "makeStarterFolder").firstMatch
        XCTAssertTrue(make.waitForExistence(timeout: 30), "an unsorted Inbox should offer starter folders")
        let name = app.textFields.matching(identifier: "starterName").firstMatch
        name.click()
        name.typeKey("a", modifierFlags: .command)
        name.typeText("Kitchen")
        make.click()
        XCTAssertTrue(folder("Kitchen").waitForExistence(timeout: 5))
        folder("Kitchen").click()
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'note-'"))
            .firstMatch.waitForExistence(timeout: 5), "its notes moved in")
    }

    /// An old Inbox note offers Archive even when sorting finds it no folder
    /// (here there are no folders at all, so every note gets "No clear match").
    func testOldInboxNoteOffersArchive() {
        app.terminate()
        app.launchArguments = ["-demo", "-unsorted"]
        app.launch()
        let card = note("Cast iron")
        XCTAssertTrue(app.buttons["makeStarterFolder"].firstMatch.waitForExistence(timeout: 30))
        // Cards are made as they scroll into view.
        for _ in 0..<20 where !card.exists { app.scrollViews["board"].scroll(byDeltaX: 0, deltaY: -400) }
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        // Read the label directly: predicate queries over labels stall here.
        let deadline = Date.now.addingTimeInterval(20)
        while !card.label.contains("Archive offered") && Date.now < deadline {
            RunLoop.current.run(until: .now.addingTimeInterval(0.5))
        }
        XCTAssertTrue(card.label.contains("Archive offered"), card.label)
    }

    /// Type, quit at once (before the 0.5 s save delay), relaunch: the text is there.
    func testQuitMidTypingKeepsText() {
        app.terminate()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("OSQuitTest-\(UUID().uuidString)").path
        app.launchArguments = ["-root", root]
        app.launch()
        app.buttons["newNoteButton"].click()
        let editor = app.textViews["noteEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.typeText("Typed right before quitting")
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 10))
        app.launch()
        XCTAssertTrue(note("Typed right before quitting").waitForExistence(timeout: 10))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root + "/Inbox/Typed right before quitting.md"))
    }

    func testSettingsAndFeedbackOpen() {
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(app.windows.containing(.staticText, identifier: "Notes folder").firstMatch.waitForExistence(timeout: 5)
                      || app.staticTexts["Notes folder"].waitForExistence(timeout: 5))
        app.typeKey("w", modifierFlags: .command)
        app.buttons["feedbackButton"].click()
        XCTAssertTrue(app.buttons["Open in Browser"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Open in Browser"].isEnabled, "empty feedback can't be sent")
        app.buttons["Cancel"].click()
    }
}
