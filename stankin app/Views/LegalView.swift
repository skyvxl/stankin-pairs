import SwiftUI

// MARK: - Privacy Policy

struct PrivacyPolicyView: View {
    var body: some View {
        LegalDocumentView(document: .privacyPolicy)
            .navigationTitle("Конфиденциальность")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
    }
}

// MARK: - Terms of Use

struct TermsOfUseView: View {
    var body: some View {
        LegalDocumentView(document: .termsOfUse)
            .navigationTitle("Условия использования")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
    }
}

// MARK: - Generic document renderer

private struct LegalDocumentView: View {
    let document: LegalDocument

    var body: some View {
        ZStack {
            ScheduleBackdrop(style: .sheet)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Обновлено: \(document.updatedAt)")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .padding(.bottom, 28)

                    ForEach(document.sections) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.header)
                                .font(.headline.weight(.semibold))

                            Text(section.body)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineSpacing(3)
                        }
                        .padding(.bottom, 26)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
        }
    }
}

// MARK: - Data

private struct LegalSection: Identifiable {
    let id = UUID()
    let header: String
    let body: String
}

private struct LegalDocument {
    let updatedAt: String
    let sections: [LegalSection]

    // MARK: Privacy Policy

    static let privacyPolicy = LegalDocument(
        updatedAt: "7 апреля 2026 г.",
        sections: [
            LegalSection(
                header: "О приложении",
                body: "Pairs — личный некоммерческий iOS-проект для просмотра расписания МГТУ «СТАНКИН». Приложение не аффилировано с университетом и не является его официальным продуктом."
            ),
            LegalSection(
                header: "Сбор данных",
                body: "Приложение не собирает, не хранит и не передаёт никаких данных о пользователе — ни на серверы разработчика, ни третьим лицам. Не требуются регистрация, авторизация или ввод личных данных. Доступ к геолокации, камере, микрофону и контактам не запрашивается."
            ),
            LegalSection(
                header: "Данные расписания",
                body: "Расписание получено путём автоматизированного парсинга PDF-файлов с учебной платформы МГТУ «СТАНКИН» с использованием учётных данных разработчика. Эти данные не предоставляются университетом официально.\n\nПосле выбора группы JSON-файл загружается из публичного репозитория разработчика на GitHub и кэшируется локально на вашем устройстве. Разработчик не получает эти данные — они хранятся только у вас."
            ),
            LegalSection(
                header: "Аналитика и нейросети",
                body: "Приложение не использует инструменты аналитики, рекламные SDK или счётчики. Действия пользователя не отслеживаются. Никакие данные не передаются для обучения нейросетей, языковых моделей или иных ИИ-систем."
            ),
            LegalSection(
                header: "Сторонние сервисы",
                body: "Единственный внешний запрос — загрузка JSON-файла расписания из публичного репозитория разработчика на GitHub. GitHub может обрабатывать технические данные запроса (например, IP-адрес) в соответствии со своей политикой конфиденциальности."
            ),
            LegalSection(
                header: "Прекращение работы",
                body: "Приложение является личной инициативой. По запросу МГТУ «СТАНКИН» или иных уполномоченных лиц доступ к данным расписания может быть ограничен или приложение закрыто — без предварительного уведомления пользователей."
            ),
            LegalSection(
                header: "Контакты",
                body: "По вопросам, связанным с политикой конфиденциальности: skyvxl@icloud.com"
            ),
        ]
    )

    // MARK: Terms of Use

    static let termsOfUse = LegalDocument(
        updatedAt: "7 апреля 2026 г.",
        sections: [
            LegalSection(
                header: "Статус приложения",
                body: "Pairs — личный некоммерческий проект, созданный из любопытства для удобного просмотра расписания. Приложение не является официальным и не аффилировано с МГТУ «СТАНКИН»."
            ),
            LegalSection(
                header: "Расписание «как есть»",
                body: "Данные расписания получены путём автоматизированного парсинга PDF-файлов и не предоставляются официально университетом. Точность не гарантируется.\n\nДля принятия учебных решений всегда сверяйтесь с официальными источниками МГТУ «СТАНКИН»."
            ),
            LegalSection(
                header: "Ограничение ответственности",
                body: "Приложение предоставляется «как есть», без каких-либо гарантий. Разработчик не несёт ответственности за неточности в расписании или последствия их использования."
            ),
            LegalSection(
                header: "Прекращение работы",
                body: "Поскольку проект неофициальный, по требованию МГТУ «СТАНКИН» или иных уполномоченных лиц приложение может быть закрыто, а доступ к данным — прекращён без предварительного уведомления."
            ),
            LegalSection(
                header: "Контакты",
                body: "По вопросам об условиях использования: skyvxl@icloud.com"
            ),
        ]
    )
}
