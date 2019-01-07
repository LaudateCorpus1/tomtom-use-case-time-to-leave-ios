import UIKit

class TrafficUpdateViewController: UIViewController {
    @IBOutlet weak var labelTrafficMessage: UILabel!
    var message: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        labelTrafficMessage.text = message
    }
    
    @IBAction func close(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
}
