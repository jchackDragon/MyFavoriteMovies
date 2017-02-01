//
//  LoginViewController.swift
//  MyFavoriteMovies
//
//  Created by Jarrod Parkes on 1/23/15.
//  Copyright (c) 2015 Udacity. All rights reserved.
//

import UIKit

// MARK: - LoginViewController: UIViewController

class LoginViewController: UIViewController {
    
    // MARK: Properties
    
    var appDelegate: AppDelegate!
    var keyboardOnScreen = false
    
    // MARK: Outlets
    
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var loginButton: BorderedButton!
    @IBOutlet weak var debugTextLabel: UILabel!
    @IBOutlet weak var movieImageView: UIImageView!
        
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // get the app delegate
        appDelegate = UIApplication.shared.delegate as! AppDelegate
        
        configureUI()
        
        subscribeToNotification(.UIKeyboardWillShow, selector: #selector(keyboardWillShow))
        subscribeToNotification(.UIKeyboardWillHide, selector: #selector(keyboardWillHide))
        subscribeToNotification(.UIKeyboardDidShow, selector: #selector(keyboardDidShow))
        subscribeToNotification(.UIKeyboardDidHide, selector: #selector(keyboardDidHide))
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unsubscribeFromAllNotifications()
    }
    
    // MARK: Login
    
    @IBAction func loginPressed(_ sender: AnyObject) {
        
        userDidTapView(self)
        
        if usernameTextField.text!.isEmpty || passwordTextField.text!.isEmpty {
            debugTextLabel.text = "Username or Password Empty."
        } else {
            setUIEnabled(false)
            
            /*
                Steps for Authentication...
                https://www.themoviedb.org/documentation/api/sessions
                
                Step 1: Create a request token
                Step 2: Ask the user for permission via the API ("login")
                Step 3: Create a session ID
                
                Extra Steps...
                Step 4: Get the user id ;)
                Step 5: Go to the next view!            
            */
            getRequestToken()
        }
    }
    
    private func completeLogin() {
        performUIUpdatesOnMain {
            self.debugTextLabel.text = ""
            self.setUIEnabled(true)
            let controller = self.storyboard!.instantiateViewController(withIdentifier: "MoviesTabBarController") as! UITabBarController
            self.present(controller, animated: true, completion: nil)
        }
    }
    
    // MARK: TheMovieDB
    
    private func getRequestToken() {
        
        /* TASK: Get a request token, then store it (appDelegate.requestToken) and login with the token */
        
        /* 1. Set the parameters */
        let methodParameters = [
            Constants.TMDBParameterKeys.ApiKey: Constants.TMDBParameterValues.ApiKey
        ]
        
        /* 2/3. Build the URL, Configure the request */
        let request = URLRequest(url: appDelegate.tmdbURLFromParameters(methodParameters as [String:AnyObject], withPathExtension: "/authentication/token/new"))
        
        /* 4. Make the request */
        let task = appDelegate.sharedSession.dataTask(with: request) { (data, response, error) in
            
            /* 5. Parse the data */
            print(request.url!)
            
            func displayError(_ error: String){
               
                print(error)
                performUIUpdatesOnMain {
                    self.setUIEnabled(true)
                    self.debugTextLabel!.text = "Ther was an error, please try leater"
                }
                
            }
            
            guard (error == nil) else{
                displayError("The was a error in your request: \(error)")
                return
            }
            
            guard let stat = (response as? HTTPURLResponse)?.statusCode, stat >= 200 && stat <= 299 else{
                displayError("Your request returned a status code other than 2xx")
                return
            }
             /* 6. Use the data! */
            guard let data = data else{
                displayError("No data was returned by this request!")
                return
            }
            
            let parsedResult:AnyObject!
            
            do{
                parsedResult = try! JSONSerialization.jsonObject(with: data, options: .allowFragments) as AnyObject!
            }catch{
                displayError("Cannot parse the data returned as JSON: \(data)")
            }
            
            
            if let _ = parsedResult[Constants.TMDBResponseKeys.StatusCode] as? Int{
                displayError("TheMovieDB returned an error. See the '\(Constants.TMDBResponseKeys.StatusCode)' and \(Constants.TMDBResponseKeys.StatusMessage)")
                
                return
            }
            
            guard let requestToken = parsedResult[Constants.TMDBResponseKeys.RequestToken] as? String else{
                displayError("Cannot find key '\(Constants.TMDBResponseKeys.RequestToken)' in \(parsedResult)")
                return
            }
            
            self.appDelegate.requestToken = requestToken
            self.loginWithToken(self.appDelegate.requestToken!)
        }

        /* 7. Start the request */
        task.resume()
    }
    
    private func loginWithToken(_ requestToken: String) {
        
        /* TASK: Login, then get a session id */
        
        if !(usernameTextField.text!.isEmpty && passwordTextField.text!.isEmpty){
        
        /* 1. Set the parameters */
        let methodParameters = [
            Constants.TMDBParameterKeys.ApiKey: Constants.TMDBParameterValues.ApiKey
            ,Constants.TMDBParameterKeys.Username: usernameTextField.text!
            ,Constants.TMDBParameterKeys.Password: passwordTextField.text!
            ,Constants.TMDBParameterKeys.RequestToken: requestToken
        ]
            
        /* 2/3. Build the URL, Configure the request */
            let request = URLRequest(url: appDelegate.tmdbURLFromParameters(methodParameters as [String: AnyObject], withPathExtension: "/authentication/token/validate_with_login"))
        /* 4. Make the request */
            
            let dataTask = appDelegate.sharedSession.dataTask(with: request, completionHandler: { (data, response, error) in
                /* 5. Parse the data */
                print(request.url!)
                
                func displayError(_ error:String){
                    
                    print(error)
                    performUIUpdatesOnMain {
                       self.setUIEnabled(true)
                       self.debugTextLabel?.text = "Login failed"
                    }
                }
                guard (error == nil) else{
                    displayError("There was an error in your request: \(error)")
                    return
                }
                
                guard let stat = (response as? HTTPURLResponse)?.statusCode, stat >= 200 && stat < 299 else{
                    displayError("The request return a status code other than 2xx")
                    return
                }
                
                guard let data = data else{
                    displayError("No data returned for this request")
                    return
                }
                
                let parsedResult:[String:AnyObject]!
                
                do{
                    parsedResult = try! JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String:AnyObject]
                }catch{
                    displayError("Cannot parse to JSON this data: \(data)")
                }
                
                if let _ = parsedResult[Constants.TMDBResponseKeys.StatusCode] as? Int{
                    displayError("TheMovieDB returned a error. See the '\(Constants.TMDBResponseKeys.StatusCode)' and '\(Constants.TMDBResponseKeys.StatusMessage)'")
                    
                    return
                }
                
                /* 6. Use the data! */
                guard let success = parsedResult[Constants.TMDBResponseKeys.Success] as? Bool, success == true else{
                    displayError("Cannot find the key '\(Constants.TMDBResponseKeys.Success)'")
                    return
                }
                
              self.getSessionID(self.appDelegate.requestToken!)
              
            })
     
        /* 7. Start the request */
            dataTask.resume()
            
        }else{
            print("The user or password are empty")
        }
    }
    
    private func getSessionID(_ requestToken: String) {
        
        /* TASK: Get a session ID, then store it (appDelegate.sessionID) and get the user's id */
        
        /* 1. Set the parameters */
        let methodParameters = [
            Constants.TMDBParameterKeys.ApiKey:Constants.TMDBParameterValues.ApiKey
            ,Constants.TMDBParameterKeys.RequestToken:requestToken
        ]
        /* 2/3. Build the URL, Configure the request */
        let request = URLRequest(url:appDelegate.tmdbURLFromParameters(methodParameters as [String:AnyObject], withPathExtension: "/authentication/session/new"))
        /* 4. Make the request */
        let dataTask = appDelegate.sharedSession.dataTask(with: request, completionHandler:{(data, response, error) in
            
            print(request.url!)
            
            func displayError(_ error:String){
                print(error)
                
                performUIUpdatesOnMain {
                    self.setUIEnabled(true)
                    self.debugTextLabel.text = "Login failed"
                }
            }
            
                guard (error == nil) else{
                    displayError("There was a error in your request: \(error)")
                    return
                }
                
                guard let stat = (response as? HTTPURLResponse)?.statusCode, stat >= 200 && stat <= 299 else{
                    displayError("The request returne status code other tham 2xx")
                    return
                }
                
                guard let data = data else{
                    displayError("No data returned for this request")
                    return
                }
                
                let parsedResult:[String:AnyObject]!
                
                /* 5. Parse the data */
                do{
                    parsedResult = try! JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String:AnyObject]
                }catch{
                    displayError("Cannot parse the data to JSON: \(data)")
                }
                
                if let _ = parsedResult[Constants.TMDBResponseKeys.StatusCode] as? Int{
                    displayError("The TheMovieDB returned a error. See '\(Constants.TMDBResponseKeys.StatusCode)' and '\(Constants.TMDBResponseKeys.StatusMessage)'")
                    
                    return
                }
                
                guard let success = parsedResult[Constants.TMDBResponseKeys.Success] as? Bool, success == true else{
                    displayError("Cannot find the key '\(Constants.TMDBResponseKeys.Success)' in \(parsedResult)")
                    return
                }
                
                guard let session_id = parsedResult[Constants.TMDBResponseKeys.SessionID] as? String else{
                    displayError("Cannot find the key '\(Constants.TMDBResponseKeys.Success)' in \(parsedResult)")
                    return
                }
                     /* 6. Use the data! */
                self.appDelegate.sessionID = session_id
                self.getUserID(self.appDelegate.sessionID!)
                //print(" Session ID = \(self.appDelegate.sessionID!)")
            
        })
        
   
        /* 7. Start the request */
        dataTask.resume()
    }
    
    private func getUserID(_ sessionID: String) {
        
        /* TASK: Get the user's ID, then store it (appDelegate.userID) for future use and go to next view! */
        
        /* 1. Set the parameters */
        let methodParameters = [
            Constants.TMDBParameterKeys.ApiKey:Constants.TMDBParameterValues.ApiKey,
            Constants.TMDBParameterKeys.SessionID: sessionID
        ]
        /* 2/3. Build the URL, Configure the request */
        let request = URLRequest(url: appDelegate.tmdbURLFromParameters(methodParameters as [String:AnyObject], withPathExtension: "/account"))
        /* 4. Make the request */
        let dataTask = appDelegate.sharedSession.dataTask(with: request, completionHandler:{(data, response, error) in
            
            print(request.url!)
            func displayError(_ error:String){
                print(error)
                performUIUpdatesOnMain {
                    self.setUIEnabled(true)
                    self.debugTextLabel.text = "Login Feild"
                }
            }
            
            guard (error == nil) else{
                displayError("There was a error in your request: \(error)")
                return
            }
            
            guard let stat = (response as? HTTPURLResponse)?.statusCode, stat >= 200 && stat <= 299 else{
                displayError("The request returned a status code other tham 2xx")
                return
            }
            
            guard let data = data else{
                displayError("The request no returned any data)")
                return
            }
            
            /* 5. Parse the data */
            let parsedResult:[String:AnyObject]!
            
            do{
                parsedResult = try! JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String:AnyObject]
            }catch{
                displayError("Cannot parse to JSON the data: \(data)")
            }
            
            if let _ = parsedResult[Constants.TMDBResponseKeys.StatusCode] as? Int{
                displayError("TheMovieDB returned a error. See the '\(Constants.TMDBResponseKeys.StatusCode)' and '\(Constants.TMDBResponseKeys.StatusMessage)'")
                return
            }
            
            guard let userID = parsedResult[Constants.TMDBResponseKeys.UserID] as? Int else{
                displayError("Cannot find the key '\(Constants.TMDBResponseKeys.UserID)' in : \(parsedResult)")
                return
            }
              /* 6. Use the data! */
            print(userID)
            
            self.appDelegate.userID = userID
            self.completeLogin()
            
        })
        
      
        /* 7. Start the request */
        dataTask.resume()
    }
}

// MARK: - LoginViewController: UITextFieldDelegate

extension LoginViewController: UITextFieldDelegate {
    
    // MARK: UITextFieldDelegate
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    // MARK: Show/Hide Keyboard
    
    func keyboardWillShow(_ notification: Notification) {
        if !keyboardOnScreen {
            view.frame.origin.y -= keyboardHeight(notification)
            movieImageView.isHidden = true
        }
    }
    
    func keyboardWillHide(_ notification: Notification) {
        if keyboardOnScreen {
            view.frame.origin.y += keyboardHeight(notification)
            movieImageView.isHidden = false
        }
    }
    
    func keyboardDidShow(_ notification: Notification) {
        keyboardOnScreen = true
    }
    
    func keyboardDidHide(_ notification: Notification) {
        keyboardOnScreen = false
    }
    
    private func keyboardHeight(_ notification: Notification) -> CGFloat {
        let userInfo = (notification as NSNotification).userInfo
        let keyboardSize = userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue
        return keyboardSize.cgRectValue.height
    }
    
    private func resignIfFirstResponder(_ textField: UITextField) {
        if textField.isFirstResponder {
            textField.resignFirstResponder()
        }
    }
    
    @IBAction func userDidTapView(_ sender: AnyObject) {
        resignIfFirstResponder(usernameTextField)
        resignIfFirstResponder(passwordTextField)
    }
}

// MARK: - LoginViewController (Configure UI)

private extension LoginViewController {
    
    func setUIEnabled(_ enabled: Bool) {
        usernameTextField.isEnabled = enabled
        passwordTextField.isEnabled = enabled
        loginButton.isEnabled = enabled
        debugTextLabel.text = ""
        debugTextLabel.isEnabled = enabled
        
        // adjust login button alpha
        if enabled {
            loginButton.alpha = 1.0
        } else {
            loginButton.alpha = 0.5
        }
    }
    
    func configureUI() {
        
        // configure background gradient
        let backgroundGradient = CAGradientLayer()
        backgroundGradient.colors = [Constants.UI.LoginColorTop, Constants.UI.LoginColorBottom]
        backgroundGradient.locations = [0.0, 1.0]
        backgroundGradient.frame = view.frame
        view.layer.insertSublayer(backgroundGradient, at: 0)
        
        configureTextField(usernameTextField)
        configureTextField(passwordTextField)
    }
    
    func configureTextField(_ textField: UITextField) {
        let textFieldPaddingViewFrame = CGRect(x: 0.0, y: 0.0, width: 13.0, height: 0.0)
        let textFieldPaddingView = UIView(frame: textFieldPaddingViewFrame)
        textField.leftView = textFieldPaddingView
        textField.leftViewMode = .always
        textField.backgroundColor = Constants.UI.GreyColor
        textField.textColor = Constants.UI.BlueColor
        textField.attributedPlaceholder = NSAttributedString(string: textField.placeholder!, attributes: [NSForegroundColorAttributeName: UIColor.white])
        textField.tintColor = Constants.UI.BlueColor
        textField.delegate = self
    }
}

// MARK: - LoginViewController (Notifications)

private extension LoginViewController {
    
    func subscribeToNotification(_ notification: NSNotification.Name, selector: Selector) {
        NotificationCenter.default.addObserver(self, selector: selector, name: notification, object: nil)
    }
    
    func unsubscribeFromAllNotifications() {
        NotificationCenter.default.removeObserver(self)
    }
}
