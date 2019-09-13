import UIKit
import SectionsTableView

class CreateWalletViewController: WalletViewController {
    private let delegate: ICreateWalletViewDelegate

    private let tableView = SectionsTableView(style: .grouped)
    private var viewItems = [CreateWalletViewItem]()

    init(delegate: ICreateWalletViewDelegate) {
        self.delegate = delegate

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "create_wallet.title".localized
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "create_wallet.create_button".localized, style: .plain, target: self, action: #selector(onTapCreate))

        tableView.registerCell(forClass: CreateWalletCell.self)
        tableView.registerHeaderFooter(forClass: TopDescriptionView.self)
        tableView.sectionDataSource = self

        tableView.backgroundColor = .clear
        tableView.allowsSelection = false
        tableView.separatorStyle = .none

        view.addSubview(tableView)
        tableView.snp.makeConstraints { maker in
            maker.edges.equalToSuperview()
        }

        delegate.viewDidLoad()
        tableView.buildSections()
    }

    @objc func onTapCreate() {
        delegate.didTapCreateButton()
    }

}

extension CreateWalletViewController: SectionsDataSource {

    func buildSections() -> [SectionProtocol] {
        let descriptionText = "create_wallet.description".localized

        let headerState: ViewState<TopDescriptionView> = .cellType(hash: "top_description", binder: { view in
            view.bind(text: descriptionText)
        }, dynamicHeight: { [unowned self] _ in
            TopDescriptionView.height(containerWidth: self.tableView.bounds.width, text: descriptionText)
        })

        return [
            Section(
                    id: "coins",
                    headerState: headerState,
                    rows: viewItems.enumerated().map { (index, viewItem) in
                        Row<CreateWalletCell>(
                                id: "coin_\(viewItem.code)",
                                height: SettingsTheme.doubleLineCellHeight,
                                bind: { [unowned self] cell, _ in
                                    cell.bind(viewItem: viewItem, last: index == self.viewItems.count - 1, onSwitch: { [weak self] isOn in
                                        self?.delegate.didToggle(index: index, isOn: isOn)
                                    })
                                }
                        )
                    }
            )
        ]
    }

}

extension CreateWalletViewController: ICreateWalletView {

    func set(viewItems: [CreateWalletViewItem]) {
        self.viewItems = viewItems
    }

    func set(createButtonEnabled: Bool) {
        navigationItem.rightBarButtonItem?.isEnabled = createButtonEnabled
    }

}