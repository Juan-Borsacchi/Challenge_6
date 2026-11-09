import Foundation
import Combine

// Controla o que a tela mostra. O acesso aos sensores fica na Store.
class CaminhadaViewModel: ObservableObject {
    enum Estado {
        case pronto, caminhando, resumo, salvo
    }

    @Published private(set) var dados = DadosCaminhada()
    @Published private var fase: Estado = .pronto
    @Published private var aguardandoAcao = false
    @Published private var encerrando = false
    @Published private var erroAcao: String?

    private let store: CaminhadaStore

    init(store: CaminhadaStore = CaminhadaStore()) {
        self.store = store
        store.$dados.assign(to: &$dados)
    }

    deinit {
        OperationQueue.main.addOperation { [store] in
            store.descartar()
        }
    }

    var estado: Estado {
        if dados.erro != nil { return .pronto }
        if fase == .caminhando && dados.terminou { return .resumo }
        return fase
    }

    var carregando: Bool {
        aguardandoAcao || (encerrando && estado == .caminhando)
    }

    var erro: String? {
        dados.erro ?? erroAcao
    }

    var tempoFormatado: String {
        let segundos = Int(dados.duracao)
        return String(format: "%02d:%02d", segundos / 60, segundos % 60)
    }

    // A tela só mostra a elevação quando existe uma leitura válida do altímetro.
    var elevacaoMaxima: Double? {
        guard dados.altitudeInicial != nil, dados.erroAltitude == nil else { return nil }
        return dados.elevacaoMaxima
    }

    func iniciar() async {
        guard estado == .pronto, !carregando else { return }
        aguardandoAcao = true
        encerrando = false
        erroAcao = nil
        defer { aguardandoAcao = false }

        if dados.erro != nil { store.descartar() }
        fase = .pronto

        do {
            try await store.iniciar()
            fase = .caminhando
        } catch {
            let mensagem = dados.erro ?? "O treino foi interrompido: \(error.localizedDescription)"
            store.descartar()
            erroAcao = mensagem
        }
    }

    func encerrar() {
        guard estado == .caminhando, !carregando else { return }
        encerrando = true
        store.encerrar()
    }

    func salvar() async {
        guard estado == .resumo, !carregando else { return }
        aguardandoAcao = true
        erroAcao = nil
        defer { aguardandoAcao = false }

        do {
            try await store.salvar()
            fase = .salvo
        } catch {
            if estado == .resumo {
                erroAcao = "Não foi possível salvar: \(error.localizedDescription)"
            }
        }
    }

    func descartar() {
        guard estado == .resumo, !carregando else { return }
        reiniciar()
    }

    func reiniciar() {
        guard estado == .resumo || estado == .salvo, !carregando else { return }
        store.descartar()
        encerrando = false
        erroAcao = nil
        fase = .pronto
    }
}
