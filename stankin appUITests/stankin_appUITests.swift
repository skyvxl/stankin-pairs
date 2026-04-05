import XCTest

final class stankin_appUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testEmptyStateShowsBottomChooseGroupButton() throws {
        let app = makeApp(arguments: ["UITEST_RESET_STATE", "UITEST_EMPTY_STATE"])
        app.launch()

        let chooseGroupButton = app.buttons["Выбрать группу"]
        XCTAssertTrue(chooseGroupButton.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(chooseGroupButton.frame.minY, app.frame.height * 0.75)
        XCTAssertLessThan(chooseGroupButton.frame.height, 60)
    }

    @MainActor
    func testGroupPickerHasBottomSearchField() throws {
        let app = makeApp(arguments: ["UITEST_RESET_STATE", "UITEST_EMPTY_STATE"])
        app.launch()

        app.buttons["Выбрать группу"].tap()

        let searchField = app.searchFields["group-picker-search-field"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(searchField.frame.minY, app.frame.height * 0.75)
    }

    @MainActor
    func testScheduleFixtureShowsLessonsAndDateControls() throws {
        let app = makeApp(arguments: ["UITEST_RESET_STATE", "UITEST_SCHEDULE_STATE"])
        app.launch()

        XCTAssertTrue(app.staticTexts["ИДБ-23-02"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Апрель 2026"].exists)
        XCTAssertTrue(app.buttons["Назад"].exists)
        XCTAssertTrue(app.buttons["Вперед"].exists)
        XCTAssertTrue(app.staticTexts["Системы цифровой обработки изображений"].exists)
        XCTAssertTrue(app.staticTexts["Организация и управление предприятием"].exists)
    }

    @MainActor
    func testScheduleFixtureSupportsSelectedDateOverride() throws {
        let app = makeApp(arguments: [
            "UITEST_RESET_STATE",
            "UITEST_SCHEDULE_STATE",
            "UITEST_SELECTED_DATE=2026-09-05",
        ])
        app.launch()

        XCTAssertTrue(app.staticTexts["Сентябрь 2026"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSettingsSheetOpensFromScheduleFixture() throws {
        let app = makeApp(arguments: ["UITEST_RESET_STATE", "UITEST_SCHEDULE_STATE"])
        app.launch()

        app.buttons["Настройки"].tap()

        XCTAssertTrue(app.staticTexts["Настройки"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Расписание"].exists)
        XCTAssertTrue(app.buttons["Сменить группу"].exists)
        XCTAssertTrue(app.buttons["Обновить расписание"].exists)
    }

    @MainActor
    func testDatePickerSheetOpensFromScheduleFixture() throws {
        let app = makeApp(arguments: ["UITEST_RESET_STATE", "UITEST_SCHEDULE_STATE"])
        app.launch()

        app.buttons["Выбрать дату"].tap()

        XCTAssertTrue(app.staticTexts["Дата"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Готово"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            makeApp(arguments: ["UITEST_RESET_STATE", "UITEST_EMPTY_STATE"]).launch()
        }
    }
}

private extension stankin_appUITests {
    @MainActor
    func makeApp(arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        return app
    }
}
