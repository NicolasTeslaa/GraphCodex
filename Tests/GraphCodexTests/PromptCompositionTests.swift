import XCTest
@testable import GraphCodex

final class PromptCompositionTests: XCTestCase {
    func testProjectContextIncludesDepartmentInstructionsAndOnlySelectedFiles() throws {
        let project = Project(id: "verval", name: "Verval", instructions: "Use o padrão de componentes do app.")
        let draft = AgentDraft(name: "UI", goal: "Ajustar navegação", role: .uiux,
                               projectID: project.id, workingDirectory: "/work/verval",
                               contextSource: .project(selectedFilePaths: ["/work/verval/README.md", "/work/verval/Sources/Nav.swift"]))

        let prompt = try PromptTemplateBuilder.build(draft: draft, project: project)

        XCTAssertTrue(prompt.contains("Use o padrão de componentes do app."))
        XCTAssertTrue(prompt.contains("/work/verval/README.md"))
        XCTAssertTrue(prompt.contains("/work/verval/Sources/Nav.swift"))
        XCTAssertFalse(prompt.contains("/work/verval/Secrets.txt"))
    }

    func testProjectContextRejectsFilesOutsideTheChosenWorkingFolder() {
        let draft = AgentDraft(name: "UI", goal: "Rever", role: .uiux,
                               projectID: "verval", workingDirectory: "/work/verval",
                               contextSource: .project(selectedFilePaths: ["/work/verval-secret/key.txt"]))

        XCTAssertThrowsError(try PromptTemplateBuilder.build(draft: draft, project: nil))
    }

    func testTemplateAddsItsGuidanceToEditablePrompt() throws {
        let draft = AgentDraft(name: "Bugfix", goal: "Corrigir falha de login", role: .backend,
                               projectID: "app", workingDirectory: "/work/app",
                               contextSource: .template(.fixBug))

        let prompt = try PromptTemplateBuilder.build(draft: draft, project: nil)

        XCTAssertTrue(prompt.contains("reproduza-o com um teste"))
        XCTAssertTrue(prompt.contains("Corrigir falha de login"))
    }
}
