import Foundation
import HSBitcoinKit
import RxSwift

class BitcoinAdapter {
    let decimal = 8

    private let bitcoinKit: BitcoinKit
    private let transactionCompletionThreshold = 6
    private let coinRate: Decimal = pow(10, 8)

    let lastBlockHeightUpdatedSignal = Signal()
    let transactionRecordsSubject = PublishSubject<[TransactionRecord]>()

    private let progressSubject: BehaviorSubject<Double>

    private(set) var state: AdapterState

    let balanceUpdatedSignal = Signal()
    let stateUpdatedSignal = Signal()

    init(words: [String], coin: BitcoinKit.Coin, walletId: String, newWallet: Bool) {
        bitcoinKit = BitcoinKit(withWords: words, coin: coin, walletId: walletId, newWallet: newWallet, minLogLevel: .error)

        progressSubject = BehaviorSubject(value: 0)
        state = .syncing(progressSubject: progressSubject)

        bitcoinKit.delegate = self
    }

    private func transactionRecord(fromTransaction transaction: TransactionInfo) -> TransactionRecord {
        let fromAddresses = transaction.from.map {
            TransactionAddress(address: $0.address, mine: $0.mine)
        }

        let toAddresses = transaction.to.map {
            TransactionAddress(address: $0.address, mine: $0.mine)
        }

        return TransactionRecord(
                transactionHash: transaction.transactionHash,
                blockHeight: transaction.blockHeight,
                amount: Decimal(transaction.amount) / coinRate,
                timestamp: Double(transaction.timestamp),
                from: fromAddresses,
                to: toAddresses
        )
    }

}

extension BitcoinAdapter: IAdapter {

    var decimal: Int {
        return 8
    }

    var balance: Decimal {
        return Decimal(bitcoinKit.balance) / coinRate
    }

    var confirmationsThreshold: Int {
        return 6
    }

    var lastBlockHeight: Int? {
        return bitcoinKit.lastBlockInfo?.height
    }

    var debugInfo: String {
        return bitcoinKit.debugInfo
    }

    var refreshable: Bool {
        return false
    }

    func start() {
        try? bitcoinKit.start()
    }

    func stop() {
    }

    func refresh() {
        // not called
    }

    func clear() {
        try? bitcoinKit.clear()
    }

    func send(to address: String, value: Decimal, completion: ((Error?) -> ())?) {
        do {
            let amount = convertToSatoshi(value: value)
            try bitcoinKit.send(to: address, value: amount)
            completion?(nil)
        } catch {
            completion?(error)
        }
    }

    func fee(for value: Decimal, address: String?, senderPay: Bool) throws -> Decimal {
        do {
            let amount = convertToSatoshi(value: value)
            let fee = try bitcoinKit.fee(for: amount, toAddress: address, senderPay: senderPay)
            return Decimal(fee) / coinRate
        } catch SelectorError.notEnough(let maxFee) {
            throw FeeError.insufficientAmount(fee: Decimal(maxFee) / coinRate)
        }
    }

    private func convertToSatoshi(value: Decimal) -> Int {
        let coinValue: Decimal = value * coinRate
        return NSDecimalNumber(decimal: ValueFormatter.instance.round(value: coinValue, scale: 0, roundingMode: .plain)).intValue
    }

    func validate(address: String) throws {
        try bitcoinKit.validate(address: address)
    }

    func parse(paymentAddress: String) -> PaymentRequestAddress {
        let paymentData = bitcoinKit.parse(paymentAddress: paymentAddress)
        return PaymentRequestAddress(address: paymentData.address, amount: paymentData.amount.map { Decimal($0) })
    }

    var receiveAddress: String {
        return bitcoinKit.receiveAddress
    }

    func transactionsSingle(hashFrom: String?, limit: Int) -> Single<[TransactionRecord]> {
        return bitcoinKit.transactions(fromHash: hashFrom, limit: limit)
                .map { [weak self] transactions -> [TransactionRecord] in
                    return transactions.compactMap {
                        self?.transactionRecord(fromTransaction: $0)
                    }
                }
    }

}

extension BitcoinAdapter: BitcoinKitDelegate {

    func transactionsUpdated(bitcoinKit: BitcoinKit, inserted: [TransactionInfo], updated: [TransactionInfo], deleted: [Int]) {
        var records = [TransactionRecord]()

        for info in inserted {
            records.append(transactionRecord(fromTransaction: info))
        }
        for info in updated {
            records.append(transactionRecord(fromTransaction: info))
        }

        transactionRecordsSubject.onNext(records)
    }

    func balanceUpdated(bitcoinKit: BitcoinKit, balance: Int) {
        balanceUpdatedSignal.notify()
    }

    func lastBlockInfoUpdated(bitcoinKit: BitcoinKit, lastBlockInfo: BlockInfo) {
        lastBlockHeightUpdatedSignal.notify()
    }

    public func kitStateUpdated(state: BitcoinKit.KitState) {
        switch state {
        case .synced:
            if case .synced = self.state {
                // do nothing
            } else {
                self.state = .synced
                stateUpdatedSignal.notify()
            }
        case .notSynced:
            if case .notSynced = self.state {
                // do nothing
            } else {
                self.state = .notSynced
                stateUpdatedSignal.notify()
            }
        case .syncing(let progress):
            progressSubject.onNext(progress)

            if case .syncing = self.state {
                // do nothing
            } else {
                self.state = .syncing(progressSubject: progressSubject)
                stateUpdatedSignal.notify()
            }
        }
    }

}

extension BitcoinAdapter {

    static func bitcoinAdapter(authData: AuthData, newWallet: Bool, testMode: Bool) -> BitcoinAdapter {
        let network: BitcoinKit.Network = testMode ? .testNet : .mainNet
        return BitcoinAdapter(words: authData.words, coin: .bitcoin(network: network), walletId: authData.walletId, newWallet: newWallet)
    }

    static func bitcoinCashAdapter(authData: AuthData, newWallet: Bool, testMode: Bool) -> BitcoinAdapter {
        let network: BitcoinKit.Network = testMode ? .testNet : .mainNet
        return BitcoinAdapter(words: authData.words, coin: .bitcoinCash(network: network), walletId: authData.walletId, newWallet: newWallet)
    }

}
