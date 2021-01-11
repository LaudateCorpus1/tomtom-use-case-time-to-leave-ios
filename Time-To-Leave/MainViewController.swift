import UIKit
import TomTomOnlineSDKSearch
import TomTomOnlineSDKRouting

class MainViewController: UIViewController, UITextFieldDelegate, UITableViewDelegate, UITableViewDataSource, CLLocationManagerDelegate, TTSearchDelegate {
    @IBOutlet weak var departureTextField: UITextField!
    @IBOutlet weak var destinationTextField: UITextField!
    @IBOutlet weak var arriveTimePicker: UIDatePicker!
    @IBOutlet weak var timePickerView: UIView!
    @IBOutlet weak var lblArriveHour: UILabel!
    @IBOutlet weak var byTaxiButton: UIButton!
    @IBOutlet weak var byCarButton: UIButton!
    @IBOutlet weak var onFootButton: UIButton!
    @IBOutlet weak var preparation0MinutesButton: UIButton!
    @IBOutlet weak var preparation5MinutesButton: UIButton!
    @IBOutlet weak var preparation10MinutesButton: UIButton!
    
    var travelMode = TTOptionTravelMode.car
    let timeShowSegueIdentifier = "timeShowSegue"
    let cellReuseIdentifier = "cell"
    var preparationTime = 0
    var autocompleteTableView: UITableView!
    let locationManager = CLLocationManager()
    var currentLocationCoords = kCLLocationCoordinate2DInvalid
    var departureCoords = kCLLocationCoordinate2DInvalid
    var destinationCoords = kCLLocationCoordinate2DInvalid
    var lastActiveTextField: UITextField?
    let dateFormatter = DateFormatter()
    let tomtomSearchAPI = TTSearch(key: Key.Search)
    var searchResults: [(address: String, coords: CLLocationCoordinate2D)] = []
    var preparationTimeButtons: [UIButton] = []
    var buttonsTravelModeMap: [UIButton: TTOptionTravelMode] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initLocationManager()
        self.departureTextField.delegate = self
        self.tomtomSearchAPI.delegate = self
        initAutoCompleteTable()
        initButtonArrays()
        initDate()
        initDefaultLocations()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    private func initDate() {
        dateFormatter.dateFormat = "H:mm"
        
        var dateComponent = DateComponents()
        dateComponent.hour = 1
        let futureDate = Calendar.current.date(byAdding: dateComponent, to: arriveTimePicker.date) ?? Date()
        arriveTimePicker.setDate(futureDate, animated: false)
        lblArriveHour.text = dateToText(arriveTimePicker.date)
        
        let timeLabelTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(toggleTimePickerView))
        lblArriveHour.addGestureRecognizer(timeLabelTapRecognizer)
    }
    
    func dateToText(_ date: Date) -> String {
        return dateFormatter.string(from: date)
    }
    
    func getArrivalDate() -> Date {
        let currentDate = Date()
        let timeComponents = (lblArriveHour.text!).components(separatedBy: ":")
        let hour = Int(timeComponents[0]) ?? 0
        let minutes = Int(timeComponents[1]) ?? 0
        let arrivalDate = Calendar.current.date(bySettingHour: hour, minute: minutes, second: 0, of: Date()) ?? currentDate
        if (arrivalDate < currentDate) {
            return Calendar.current.date(byAdding: .day, value: 1, to: arrivalDate)!
        }
        else {
            return arrivalDate
        }
    }
    
    private func initDefaultLocations() {
        self.departureTextField.text = "Oosterdoksstraat 140, 1011DK, Amsterdam"
        departureCoords = CLLocationCoordinate2D.init(latitude: 52.376522, longitude: 4.908302)
        
        self.destinationTextField.text = "Expeditiestraat, 1118, Haarlemmermeer (Schiphol)"
        destinationCoords = CLLocationCoordinate2D.init(latitude: 52.307117, longitude: 4.764237)
    }
    
    private func initButtonArrays() {
        preparationTimeButtons = [preparation0MinutesButton, preparation5MinutesButton, preparation10MinutesButton]
        buttonsTravelModeMap = [byCarButton:TTOptionTravelMode.car, byTaxiButton:TTOptionTravelMode.taxi, onFootButton:TTOptionTravelMode.pedestrian]
    }
    
    @IBAction func cancelTimePicker(_ sender: Any) {
        timePickerView.isHidden = true
    }
    
    @IBAction func okTimePicker(_ sender: Any) {
        timePickerView.isHidden = true
        lblArriveHour.text = dateToText(arriveTimePicker.date)
    }
    
    @IBAction func travelModeButtonPressed(_ sender: Any) {
        let travelModeButtonPressed = sender as! UIButton
        
        for button in buttonsTravelModeMap.keys {
            if button == travelModeButtonPressed {
                travelMode = buttonsTravelModeMap[button] ?? TTOptionTravelMode.car
            }
            button.isSelected = false
        }
        travelModeButtonPressed.isSelected = true
    }
    
    @IBAction func editingChanged(_ textView: UITextField) {
        let enteredText = textView.text
        if enteredText?.count ?? 0 >= 3 {
            lastActiveTextField = textView
            adjustAutocompleteFrame(textView)
            autocompleteTableView.isHidden = true
            let searchQuery: TTSearchQuery = TTSearchQueryBuilder.create(withTerm: enteredText ?? "").withTypeAhead(true).withLang("en-US").build()
            self.tomtomSearchAPI.search(with: searchQuery)
        }
    }
    
    func initLocationManager() {
        locationManager.requestAlwaysAuthorization()
        if (CLLocationManager.locationServicesEnabled()) {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.startUpdatingLocation()
        }
    }
    
    func initAutoCompleteTable() {
        let startPoint = departureTextField.superview?.convert(departureTextField.frame.origin, to: nil)
        autocompleteTableView = UITableView(frame: CGRect(x:startPoint!.x, y:startPoint!.y,width: departureTextField.frame.width,height: 120), style: .plain)
        autocompleteTableView.delegate = self
        autocompleteTableView.dataSource = self
        autocompleteTableView.isScrollEnabled = true
        autocompleteTableView.isHidden = true
        autocompleteTableView.register(UITableViewCell.self, forCellReuseIdentifier: self.cellReuseIdentifier)
        self.view.addSubview(autocompleteTableView)
    }
    
    func search(_ search: TTSearch, completedWith response: TTSearchResponse) {
        searchResults.removeAll()
        for result in response.results {
            let resultTuple = (result.address.freeformAddress!, result.position)
            searchResults.append(resultTuple)
        }
        if CLLocationCoordinate2DIsValid(currentLocationCoords) {
            searchResults.append(("-- Your Location --", currentLocationCoords))
            searchResults.sort() { $0.0 < $1.0 }
        }
        autocompleteTableView?.reloadData()
        autocompleteTableView.isHidden = false;
    }
    
    func search(_ search: TTSearch, failedWithError error: TTResponseError) {
        print(error.description)
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocationCoords = manager.location?.coordinate ?? kCLLocationCoordinate2DInvalid
        locationManager.stopUpdatingLocation()
    }
    
    @objc private func toggleTimePickerView() {
        timePickerView.isHidden = !timePickerView.isHidden
    }
    
    func adjustAutocompleteFrame(_ textView: UITextField) {
        let startPoint = textView.superview?.convert(textView.frame.origin, to: nil)
        autocompleteTableView.frame = CGRect(x: startPoint!.x, y: startPoint!.y + textView.frame.height, width: textView.frame.width, height: 250)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedTuple = searchResults[indexPath.item]
        lastActiveTextField?.text = selectedTuple.address
        if lastActiveTextField == departureTextField {
            departureCoords = selectedTuple.coords
        }
        else if lastActiveTextField == destinationTextField {
            destinationCoords = selectedTuple.coords
        }
        autocompleteTableView.isHidden = true
        lastActiveTextField?.resignFirstResponder()
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: self.cellReuseIdentifier, for: indexPath) as UITableViewCell
        let index = indexPath.row as Int
        cell.textLabel?.text = searchResults[index].address
        cell.textLabel?.numberOfLines = 3
        return cell
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResults.count
    }
    
    @IBAction func preparationTimeButtonPressed(_ pressedButton: UIButton) {
        for button in preparationTimeButtons {
            if button == pressedButton {
                button.layer.shadowOffset = CGSize(width: 0.0, height: 0.5)
                button.layer.shadowRadius = 7
                button.isSelected = true
            }
            else {
                button.layer.shadowOffset = CGSize(width: 0.0, height: 2.0)
                button.layer.shadowRadius = 2
                button.isSelected = false
            }
        }
        preparationTime = Int(pressedButton.titleLabel?.text ?? "0")!
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == self.timeShowSegueIdentifier {
            if !CLLocationCoordinate2DIsValid(departureCoords)
                || !CLLocationCoordinate2DIsValid(destinationCoords)
                || coordinatesAreEqual(coord1: departureCoords, coord2: destinationCoords)  {
                showDialog()
                return false
            }
        }
        return true
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == self.timeShowSegueIdentifier {
            let destViewController: CountDownViewController = segue.destination as! CountDownViewController
            destViewController.travelMode = travelMode
            destViewController.arriveAtTime = getArrivalDate()
            destViewController.preparationTime = preparationTime
            destViewController.departureLocation = departureCoords
            destViewController.destinationLocation = destinationCoords
        }
    }
    
    func showDialog() {
        let alert = UIAlertController(title: "Problem with a departure or a destination position", message: "Please choose locations from a drop down list", preferredStyle: .alert)
        let alertAction = UIAlertAction(title: "Dismiss", style: .cancel)
        alert.addAction(alertAction)
        
        present(alert, animated: true, completion: nil)
    }
    
    func coordinatesAreEqual(coord1: CLLocationCoordinate2D, coord2: CLLocationCoordinate2D) -> Bool {
        return coord1.latitude.isEqual(to: coord2.latitude)
            && coord1.longitude.isEqual(to: coord2.longitude)
    }
}
