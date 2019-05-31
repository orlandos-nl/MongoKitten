import UIKit
import MongoKitten

protocol Model: Codable {
    static var collection: String { get }
}

protocol CellModel: Model {
    associatedtype Cell: UITableViewCell
    static var cellIdentifier: String { get }

    func configureCell(_ cell: Cell) throws
}

class List<M: CellModel>: NSObject, UITableViewDataSource {
    private let users = database[M.collection]

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        do {
            return try users.count().wait()
        } catch {
            return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        do {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: M.cellIdentifier) as? M.Cell else {
                return UITableViewCell()
            }

            let instance = try users.find()
                .decode(M.self)
                .skip(indexPath.row)
                .limit(1)
                .getFirstResult()
                .wait()

            if let instance = instance {
                try instance.configureCell(cell)
            }

            return cell
        } catch {
            return UITableViewCell()
        }
    }
}

final class UserListController: UITableViewController {
    private let list = List<User>()

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.dataSource = list
    }
}

struct User: CellModel {
    typealias Cell = UserCell

    static let cellIdentifier = "user-cell"
    static let collection = "users"

    let _id: ObjectId
    var name: String

    init(named name: String) {
        self._id = ObjectId()
        self.name = name
    }

    func configureCell(_ cell: UserCell) throws {
        cell.username.text = self.name
    }
}

final class UserCell: UITableViewCell {
    @IBOutlet weak var username: UILabel!
}
