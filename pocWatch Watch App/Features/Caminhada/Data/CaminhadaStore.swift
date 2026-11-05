import Foundation
import Combine
import HealthKit
import CoreMotion

// Mantém o acesso ao estado do treino no MainActor, usado para atualizar a interface.
@MainActor
class CaminhadaStore: NSObject, ObservableObject {
    enum Estado {
        case pronto, caminhando, resumo, salvo
    }
    
    @Published private(set) var estado: Estado = .pronto
    @Published private(set) var carregando = false
    @Published private(set) var bpm: Int?
    @Published private(set) var bpmMedio: Int?
    @Published private(set) var calorias: Double?
    @Published private(set) var passos: Int?
    @Published private(set) var erroPassos: String?
    @Published private(set) var inicio = Date()
    @Published private(set) var duracao: TimeInterval = 0
    @Published private(set) var erro: String?
    @Published private(set) var altitudeInicial: Double?
    @Published private(set) var altitudeAtual: Double?
    @Published private(set) var altitudeFinal: Double?
    @Published private(set) var erroAltitude: String?
    @Published private(set) var elevacaoMaxima: Double = 0
    
    private let healthStore = HKHealthStore()
    private let pedometro = CMPedometer()
    private var sessao: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    
    private let altimetro = CMAltimeter()
    private var leituraAltitudeID: UUID?
    
    /// Converte a duração em segundos para um texto com minutos e segundos, como "03:25".
    var tempoFormatado: String {
        let segundos = Int(duracao)
        return String(format: "%02d:%02d", segundos / 60, segundos % 60)
    }
    
    /// Solicita as permissões do Saúde e inicia a sessão, a coleta de métricas e os sensores.
    func iniciar() async {
        guard estado == .pronto, !carregando else { return }
        guard HKHealthStore.isHealthDataAvailable() else {
            erro = "HealthKit indisponível."
            return
        }
        carregando = true
        erro = nil
        // Executa ao sair da função, inclusive se houver um erro ou um return antecipado.
        defer { carregando = false }
        
        do {
            try await healthStore.requestAuthorization(toShare: [HKObjectType.workoutType()],read: [HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned)])
            
            guard healthStore.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized else {
                erro = "Permita salvar treinos no Saúde para iniciar."
                return
            }
            
            // A sessão configura os sensores para uma caminhada interna.
            let configuracao = HKWorkoutConfiguration()
            configuracao.activityType = .walking
            configuracao.locationType = .indoor
            
            // A sessão controla o treino; o builder reúne as medições e permite salvá-lo.
            let novaSessao = try HKWorkoutSession(healthStore: healthStore, configuration: configuracao)
            let novoBuilder = novaSessao.associatedWorkoutBuilder()
            sessao = novaSessao
            builder = novoBuilder
            // Esta própria CaminhadaStore receberá os avisos nos métodos da extensão abaixo.
            novaSessao.delegate = self
            novoBuilder.delegate = self
            novoBuilder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuracao)
            
            inicio = Date()
            novaSessao.startActivity(with: inicio)
            try await novoBuilder.beginCollection(at: inicio)
            // Após a espera, só continua se esta ainda for a sessão atual.
            guard sessao === novaSessao else { return }
            estado = .caminhando
            iniciarPassos()
            registrarAltitude(inicial: true)
        } catch {
            tratarFalha(error)
        }
    }
    
    /// Para a contagem de passos, solicita a altitude final e pede o encerramento da sessão.
    /// O resumo será preparado quando o HealthKit confirmar o encerramento pelo delegate.
    func encerrar() {
        guard estado == .caminhando, !carregando else { return }
        carregando = true
        pedometro.stopUpdates()
        registrarAltitude(inicial: false)
        sessao?.end()
        
    }
    
    /// Finaliza a coleta na data de encerramento e disponibiliza os resultados para o resumo.
    /// A consulta dos passos finais é assíncrona e pode terminar depois que o resumo aparecer.
    private func prepararResumo(em data: Date) async {
        guard let builder else { return }
        pedometro.stopUpdates()
        carregando = true
        defer { carregando = false }
        do {
            try await builder.endCollection(at: data)
            // Ignora o resultado se o coletor do treino tiver sido substituído ou liberado.
            guard self.builder === builder else { return }
            atualizarMetricas()
            duracao = builder.elapsedTime(at: data)
            estado = .resumo
            consultarPassosFinais(ate: data)
        } catch {
            tratarFalha(error)
        }
    }
    
    /// Salva o treino no Saúde e, após a confirmação, libera a sessão mantendo o resumo.
    /// Se o salvamento falhar, mantém o estado de resumo e informa o erro.
    func salvar() async {
        guard estado == .resumo, !carregando, let builder else { return }
        carregando = true
        erro = nil
        defer { carregando = false }
        do {
            guard try await builder.finishWorkout() != nil else {
                erro = "O Saúde não confirmou o salvamento."
                return
            }
            liberarSessao()
            estado = .salvo
        } catch {
            erro = "Não foi possível salvar: \(error.localizedDescription)"
        }
    }
    
    /// Descarta o treino ainda não salvo e limpa os dados para voltar à tela inicial.
    func descartar() {
        guard estado == .resumo, !carregando else { return }
        builder?.discardWorkout()
        reiniciar()
    }
    
    /// Sai do resumo ou da confirmação de salvamento e prepara os dados para outro treino.
    func reiniciar() {
        guard estado == .resumo || estado == .salvo else { return }
        limparTreino()
    }
    
    /// Lê as estatísticas já reunidas pelo builder: BPM recente, BPM médio e calorias totais.
    /// Atualiza as propriedades observadas pela tela; não inicia uma nova coleta de sensores.
    private func atualizarMetricas() {
        guard let builder else { return }
        let unidadeBPM = HKUnit.count().unitDivided(by: .minute())
        let batimentos = builder.statistics(for: HKQuantityType(.heartRate))
        if let valor = batimentos?.mostRecentQuantity()?.doubleValue(for: unidadeBPM) {
            bpm = Int(valor.rounded())
        }
        if let media = batimentos?.averageQuantity()?.doubleValue(for: unidadeBPM) {
            bpmMedio = Int(media.rounded())
        }
        calorias = builder.statistics(for: HKQuantityType(.activeEnergyBurned))?
            .sumQuantity()?.doubleValue(for: .kilocalorie())
    }
    
    /// Acompanha o total de passos contado pelo pedômetro desde o início da caminhada.
    private func iniciarPassos() {
        guard CMPedometer.isStepCountingAvailable() else {
            erroPassos = "Contagem de passos indisponível neste dispositivo."
            return
        }
        let inicioDaContagem = inicio
        // weak self evita que a leitura mantenha esta store viva caso ela seja liberada.
        pedometro.startUpdates(from: inicioDaContagem) { [weak self] dados, error in
            Task { @MainActor in
                // Só aceita a leitura se a store existir e o mesmo treino ainda estiver em andamento.
                guard let self, self.inicio == inicioDaContagem,
                      self.estado == .caminhando, !self.carregando else { return }
                if let error {
                    self.erroPassos = "Passos indisponíveis: \(error.localizedDescription)"
                } else if let dados {
                    // O pedômetro já retorna o total desde o início; não somamos novamente.
                    self.passos = dados.numberOfSteps.intValue
                    self.erroPassos = nil
                }
            }
        }
    }
    
    /// Consulta os passos entre o início e o fim do treino para atualizar o total do resumo.
    private func consultarPassosFinais(ate fim: Date) {
        guard CMPedometer.isStepCountingAvailable() else { return }
        let inicioDaContagem = inicio
        // Consulta apenas o intervalo do treino, sem incluir passos após o encerramento.
        pedometro.queryPedometerData(from: inicioDaContagem, to: fim) { [weak self] dados, error in
            Task { @MainActor in
                guard let self, self.inicio == inicioDaContagem,
                      self.estado == .resumo || self.estado == .salvo else { return }
                if let error {
                    self.erroPassos = "Passos indisponíveis: \(error.localizedDescription)"
                } else if let dados {
                    self.passos = dados.numberOfSteps.intValue
                    self.erroPassos = nil
                }
            }
        }
    }
    
    /// Com inicial = true, guarda a primeira altitude e continua acompanhando a elevação máxima.
    /// Com inicial = false, aguarda uma leitura para guardar a altitude final e para o altímetro.
    private func registrarAltitude(inicial: Bool) {
        // Interrompe a leitura anterior e invalida os resultados que ainda possam estar a caminho.
        altimetro.stopAbsoluteAltitudeUpdates()
        leituraAltitudeID = nil
        erroAltitude = nil
        
        // Confere se o dispositivo oferece medição de altitude absoluta.
        guard CMAltimeter.isAbsoluteAltitudeAvailable() else {
            erroAltitude = "Não foi possível iniciar o altímetro"
            return
        }
        
        // Cada pedido tem um identificador para distinguir suas respostas das leituras anteriores.
        let pedidoID = UUID()
        leituraAltitudeID = pedidoID
        
        altimetro.startAbsoluteAltitudeUpdates(to: .main) { [weak self] dados, erro in
            let altitude = dados?.altitude
            let mensagemErro = erro?.localizedDescription
            
            Task { @MainActor in
                
                // Ignora respostas de um pedido que já foi cancelado ou substituído.
                guard let self, self.leituraAltitudeID == pedidoID else { return }
                
                if let mensagemErro {
                    self.altimetro.stopAbsoluteAltitudeUpdates()
                    self.leituraAltitudeID = nil
                    self.erroAltitude = mensagemErro
                    return
                }
                
                guard let altitude else { return }
                
                if !inicial {
                    self.altimetro.stopAbsoluteAltitudeUpdates()
                    self.leituraAltitudeID = nil
                }
                
                if inicial {
                    // Guarda o ponto de partida somente na primeira leitura.
                    if self.altitudeInicial == nil {
                        self.altitudeInicial = altitude
                    }
                } else {
                    self.altitudeFinal = altitude
                }

                // Guarda a maior altura acima do ponto inicial, em metros; não soma todas as subidas.
                if let pontoInicial = self.altitudeInicial {
                    let elevacao = altitude - pontoInicial

                    self.elevacaoMaxima = max(self.elevacaoMaxima, elevacao)
                }
            }
        }
    }
    
    /// Para o pedômetro e remove os delegates e as referências à sessão e ao builder.
    /// Preserva as métricas para que continuem visíveis após salvar o treino.
    private func liberarSessao() {
        pedometro.stopUpdates()
        sessao?.delegate = nil
        builder?.delegate = nil
        sessao = nil
        builder = nil
    }
    
    /// Libera a sessão, para o altímetro e redefine os resultados para iniciar outro treino.
    private func limparTreino() {
        liberarSessao()
        bpm = nil
        bpmMedio = nil
        calorias = nil
        passos = nil
        erroPassos = nil
        duracao = 0
        erro = nil
        estado = .pronto
        
        leituraAltitudeID = nil
        altimetro.stopAbsoluteAltitudeUpdates()
        
        altitudeInicial = nil
        altitudeFinal = nil
        erroAltitude = nil
        elevacaoMaxima = 0
    }
    
    /// Interrompe a sessão, descarta a coleta e volta ao estado inicial com uma mensagem de erro.
    private func tratarFalha(_ error: Error) {
        sessao?.delegate = nil
        sessao?.end()
        builder?.discardWorkout()
        limparTreino()
        carregando = false
        erro = "O treino foi interrompido: \(error.localizedDescription)"
    }
}

// Esta extensão reúne os métodos que o HealthKit chama para avisar sobre o treino.
// nonisolated permite receber esses avisos fora do MainActor. Cada Task passa o tratamento
// para o MainActor antes de acessar o estado da store. As comparações com === verificam
// se o aviso pertence ao mesmo objeto de sessão ou builder usado no treino atual.
extension CaminhadaStore: HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    /// Recebe mudanças no estado da sessão e prepara o resumo quando ela termina.
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        Task { @MainActor in
            guard self.sessao === workoutSession else { return }
            if toState == .ended {
                await self.prepararResumo(em: date)
            }
        }
    }
    
    /// Recebe uma falha da sessão atual e aciona a limpeza do treino e a exibição do erro.
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in
            guard self.sessao === workoutSession else { return }
            self.tratarFalha(error)
        }
    }
    
    /// Recebe o aviso de novas medições e atualiza os batimentos e as calorias exibidos na tela.
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        Task { @MainActor in
            guard self.builder === workoutBuilder else { return }
            self.atualizarMetricas()
        }
    }
    
    /// Exigido pelo protocolo para avisos de eventos, como pausas. Este app não os trata aqui.
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) { }
}
