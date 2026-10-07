import Foundation

struct HandledCodexServerRequest {
    var response: [String: Any]
    var notice: String?
}

enum CodexServerRequestRouter {
    static func response(for request: [String: Any]) -> HandledCodexServerRequest? {
        guard let method = request["method"] as? String, let id = request["id"] else { return nil }
        let isApproval = method.hasSuffix("/requestApproval")
        let message = isApproval
            ? "O app-server roteou uma aprovação para o GraphCodex. Nenhuma ação foi aprovada. Abra a conversa no Codex; se a aprovação não estiver disponível lá, inicie o turno pelo Codex."
            : "O GraphCodex não oferece suporte à solicitação do app-server: \(method)."
        return HandledCodexServerRequest(
            response: ["id": id, "error": ["code": -32601, "message": message]],
            notice: isApproval ? message : nil
        )
    }
}
