import UIKit

class OverTimeViewController: UIViewController {
    var parentDelegate: UIViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    @IBAction func close(_ sender: Any) {
        dismiss(animated: true, completion: {
            self.parentDelegate?.dismiss(animated: true, completion: nil)
        })
    }
}
