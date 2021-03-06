class TransactionInfoAddressMapper {
    private static let map = [
        "0x7a250d5630b4cf539739df2c5dacb4c659f2488d": "Uniswap v.2"
    ]

    static func map(_ value: String) -> String {
        title(value: value) ?? value
    }

    static func title(value: String) -> String? {
        map[value.lowercased()]
    }

}
