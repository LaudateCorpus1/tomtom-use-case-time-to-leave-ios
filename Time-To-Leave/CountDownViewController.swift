import UIKit
import TomTomOnlineSDKMaps
import TomTomOnlineSDKRouting

class CountDownViewController: UIViewController, TTRouteResponseDelegate{
    @IBOutlet weak var labelPrepTime: UILabel!
    @IBOutlet weak var labelTravelTime: UILabel!
    @IBOutlet weak var imageTravelIcon: UIImageView!
    @IBOutlet weak var labelHour: UILabel!
    @IBOutlet weak var labelMinutes: UILabel!
    @IBOutlet weak var labelSeconds: UILabel!
    @IBOutlet weak var countDownView: UIView!
    
    var mapView: TTMapView!
    let ttRoute = TTRoute(key: Key.Routing)
    var travelMode: TTOptionTravelMode!
    var arriveAtTime: Date!
    var travelTimeInSeconds: Int? {
        didSet {
            displayTravelTime(travelTimeInSeconds ?? 0)
        }
    }
    var preparationTime: Int?
    var previousDepartureTime: Date!
    var departureLocation: CLLocationCoordinate2D!
    var destinationLocation: CLLocationCoordinate2D!
    var progressDialog: UIViewController!
    var countDownTimer: Timer?
    var countDownSeconds: Int = 0
    let safeTravelsSegueIdentifier = "safeTravelsSegue"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initProgressDialog()
        setTravelIcon()
        setPreparationTimeString()
        initTomTomServices()
    }
    
    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        super.dismiss(animated: flag, completion: completion)
        resetTimer()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == self.safeTravelsSegueIdentifier {
            let destViewController: SafeTravelsViewController = segue.destination as! SafeTravelsViewController
            destViewController.parentDelegate = self
        }
    }
    
    @IBAction func backButtonPressed(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    fileprivate func initTomTomMap() {
        let style = TTMapStyleDefaultConfiguration()
        let config = TTMapConfigurationBuilder.create()
            .withMapKey(Key.Map)
            .withTrafficKey(Key.Traffic)
            .withMapStyleConfiguration(style)
            .build()
        self.mapView = TTMapView(frame: self.view.frame, mapConfiguration: config)
        self.view.insertSubview(mapView, belowSubview: countDownView)
        self.mapView.translatesAutoresizingMaskIntoConstraints = false
        self.mapView.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
        self.mapView.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true
        self.mapView.topAnchor.constraint(equalTo: self.countDownView.bottomAnchor).isActive = true
        self.mapView.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor).isActive = true
    }
    
    fileprivate func initTomTomServices() {
        initTomTomMap()
        self.ttRoute.delegate = self
        let insets = UIEdgeInsets.init(top: 30 * UIScreen.main.scale, left: 10 * UIScreen.main.scale, bottom: 30 * UIScreen.main.scale, right:10 * UIScreen.main.scale)
        self.mapView.contentInset = insets
        self.mapView.onMapReadyCompletion {
            self.mapView.isShowsUserLocation = true
            self.present(self.progressDialog, animated: true, completion: nil)
            self.requestRouteUpdate()
        }
    }
    
    fileprivate func initStoryBoardDialog(identifier: String) -> UIViewController {
        let mainStoryBoard = UIStoryboard.init(name: "Main", bundle: nil)
        return mainStoryBoard.instantiateViewController(withIdentifier:identifier)
    }
    
    fileprivate func initProgressDialog() {
        self.progressDialog = initStoryBoardDialog(identifier: "progressDialog")
    }
    
    fileprivate func setPreparationTimeString() {
        labelPrepTime.text = "\(preparationTime ?? 0) MIN PREP"
    }
    
    fileprivate func setTravelIcon() {
        let imageTravelModeMap = [TTOptionTravelMode.car: #imageLiteral(resourceName: "ic_car"),
                                  TTOptionTravelMode.taxi: #imageLiteral(resourceName: "ic_cab"),
                                  TTOptionTravelMode.pedestrian: #imageLiteral(resourceName: "ic_walk")]
        imageTravelIcon.image = imageTravelModeMap[travelMode]
    }
    
    fileprivate func displayTravelTime(_ travelTimeInSeconds: Int) {
        let hms = secondsToHoursMinutesSecondsTuple(travelTimeInSeconds: travelTimeInSeconds)
        if hms.hours > 0 {
            labelTravelTime.text = "TRAVEL \(hms.hours)h \(hms.minutes)MIN"
        }
        else {
            labelTravelTime.text = "TRAVEL \(hms.minutes)MIN"
        }
    }
    
    func route(_ route: TTRoute, completedWith result: TTRouteResult) {
        func startTimer() {
            self.countDownTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateTimer), userInfo: nil, repeats: true)
        }
        
        func drawRouteOnTomTomMap(_ route: TTFullRoute) {
            let mapRoute = TTMapRoute(coordinatesData: route,
                                      with: TTMapRouteStyle.defaultActive(),
                                      imageStart: TTMapRoute.defaultImageDeparture(),
                                      imageEnd: TTMapRoute.defaultImageDestination())
            mapView.routeManager.add(mapRoute)
            
            mapView.routeManager.showRouteOverview(mapRoute)
        }
        
        func presentTrafficUpdateDialog(message: String) {
            let trafficChangedDialog = initStoryBoardDialog(identifier: "trafficUpdateMessage")
            (trafficChangedDialog as! TrafficUpdateViewController).message = message
            presentTrafficDialog(viewController: trafficChangedDialog)
        }
        
        func presentTrafficDialog(viewController: UIViewController, for seconds: Double = 3.0) {
            self.present(viewController, animated: true)
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + seconds) {
                viewController.dismiss(animated: true)
            }
        }
        
        guard let plannedRoute = result.routes.first else {
            return
        }
        
        self.progressDialog.dismiss(animated: true, completion: nil)
        let newDepartureTime = plannedRoute.summary.departureTime
        
        self.travelTimeInSeconds = plannedRoute.summary.travelTimeInSecondsValue
        if (self.previousDepartureTime == nil) {
            self.previousDepartureTime = newDepartureTime
            drawRouteOnTomTomMap(plannedRoute)
            startTimer()
            updateTimer()
        }
        else if self.previousDepartureTime != newDepartureTime {
            presentTrafficUpdateDialog(message: "Route recalculated due to change in traffic: \(Int(self.previousDepartureTime.timeIntervalSince(newDepartureTime)))sec")
            self.previousDepartureTime = newDepartureTime
        }
        else if self.previousDepartureTime == newDepartureTime {
            let noTrafficDialog = initStoryBoardDialog(identifier: "trafficNoUpdateMessage")
            presentTrafficDialog(viewController: noTrafficDialog)
        }
    }
    
    func route(_ route: TTRoute, completedWith responseError: TTResponseError) {
        func displayErrorDialog() {
            let alertDialog = UIAlertController(title: "Error", message: "No routes found satisfying requested time. Please choose different arrival time and try again." , preferredStyle: .alert)
            let dialogAction = UIAlertAction(title: "Dismiss", style: .default, handler:  { _ in
                self.dismiss(animated: true, completion: nil)
            })
            alertDialog.addAction(dialogAction)
            self.present(alertDialog, animated: true, completion: nil)
        }
        
        self.progressDialog.dismiss(animated: true, completion: {
            if self.previousDepartureTime == nil {
                displayErrorDialog()
            }
        })
    }
    
    @objc func updateTimer() {
        func prepareFinalAlert() -> UIAlertController {
            let timeToLeaveAlert = UIAlertController(title: "Time's UP!", message: "Time to leave!", preferredStyle: .alert)
            let timeToLeaveWhateverAction = UIAlertAction(title: "Whatever", style: .default, handler: { _ in
                let overTimeDialog = self.initStoryBoardDialog(identifier: "overtimeDialog")
                (overTimeDialog as! OverTimeViewController).parentDelegate = self
                self.present(overTimeDialog, animated: true, completion: nil)
            })
            let onMyWayAction = UIAlertAction(title: "On My Way!", style: .default, handler: { _ in
                self.performSegue(withIdentifier: self.safeTravelsSegueIdentifier, sender: self)
            })
            timeToLeaveAlert.addAction(timeToLeaveWhateverAction)
            timeToLeaveAlert.addAction(onMyWayAction)
            return timeToLeaveAlert
        }
        
        let routeRecalculationDelayInSeconds = 60
        countDownSeconds += 1
        let currentTime = Date()
        if currentTime < previousDepartureTime {
            let timeInterval = DateInterval(start: currentTime, end: self.previousDepartureTime)
            displayTimeToLeave(timeInterval)
            
            if countDownSeconds % routeRecalculationDelayInSeconds == 0
                && timeInterval.duration > 5 {
                self.requestRouteUpdate()
            }
        }
        else {
            resetTimer()
            let finalTimeToLeaveAlert = prepareFinalAlert()
            self.present(finalTimeToLeaveAlert, animated: true, completion: nil)
        }
    }
    
    fileprivate func resetTimer() {
        countDownTimer?.invalidate()
        countDownSeconds = 0
    }
    
    fileprivate func displayTimeToLeave(_ timeToLeave: DateInterval) {
        let hmsTuple = secondsToHoursMinutesSecondsTuple(travelTimeInSeconds: Int(timeToLeave.duration))
        labelHour.text = "\(hmsTuple.hours)h"
        labelMinutes.text = "\(hmsTuple.minutes)min"
        labelSeconds.text = "\(hmsTuple.seconds)sec"
    }
    
    fileprivate func requestRouteUpdate() {
        let routeQuery = TTRouteQueryBuilder.create(withDest: self.destinationLocation, andOrig: self.departureLocation)
            .withArriveAt(self.arriveAtTime)
            .withTraffic(true)
            .withTravelMode(self.travelMode)
            .withRouteType(.fastest)
            .build()
        self.ttRoute.plan(with: routeQuery)
    }
    
    fileprivate func secondsToHoursMinutesSecondsTuple(travelTimeInSeconds: Int) -> (hours:Int, minutes:Int, seconds:Int) {
        let ONE_HOUR_IN_SECONDS = 3600
        let ONE_MINUTE_IN_SECONDS = 60
        func getHours() -> Int {
            return travelTimeInSeconds / ONE_HOUR_IN_SECONDS
        }
        
        func getMinutes() -> Int {
            return (travelTimeInSeconds % ONE_HOUR_IN_SECONDS) / ONE_MINUTE_IN_SECONDS
        }
        
        func getSeconds() -> Int {
            return (travelTimeInSeconds % ONE_HOUR_IN_SECONDS) % ONE_MINUTE_IN_SECONDS
        }
        let hours = getHours()
        let minutes = getMinutes()
        let seconds = getSeconds()
        return (hours, minutes, seconds)
    }
}
