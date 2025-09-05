//
//  ViewController.swift
//  ProveAppDemo
//
//  Created by Margels on 24/06/25.
//

import UIKit
import ProveAuth

class ViewController: UIViewController {
    
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private var proveAuthInstance: ProveAuth?
    
    @IBOutlet var phoneNumberTextField: UITextField!
    @IBOutlet var authButton: UIButton!
    @IBOutlet var resultLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        authButton.setTitle("Start Authentication", for: .normal)
        self.updateResultLabel(with: "")
        
        activityIndicator.center = view.center
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)
    }
    

    @IBAction func authButtonTapped(_ sender: Any) {
        startUnify()
    }
    
    private func startProveSdk() {
        // Fetch required data first
        guard let phoneNumber = phoneNumberTextField.text,
              !phoneNumber.isEmpty,
              phoneNumber.count > 9
        else {
            self.updateResultLabel(with: "Please enter a valid phone number.")
            return
        }
        
        // Warn the user authentication process has started
        self.updateResultLabel(with: "Authenticating...")
        
        // Begin authentication
        DataService.shared.authenticate(
            phoneNumber: phoneNumber
        ) { result in
            
            // Fetch result
            switch result {
                
            // Set the authentication flow with OTP fallback
            case .success(let authToken):
                self.updateResultLabel(with: "Got auth token! Starting SDK...")
                let authFinishStep = AuthFinishHandler(onResult: self.onResult)
                let otpStartStep = OtpStartHandler(presentingViewController: self)
                let otpFinishStep = OtpFinishHandler(presentingViewController: self)
                self.proveAuthInstance = ProveAuth.builder(authFinish: authFinishStep)
                    .withMobileAuthTestMode()
                    .withOtpFallback(otpStart: otpStartStep, otpFinish: otpFinishStep)
                    .build()
                self.proveAuthInstance?.authenticate(authToken: authToken) { [weak self] error in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        if let failureReason = error.failureReason {
                            self.updateResultLabel(with: "Error: \(failureReason)")
                        } else {
                            self.updateResultLabel(with: "Authentication Success!")
                        }
                    }
                }
                
            // Warn user the authentication process failed
            case .failure(let error):
                self.updateResultLabel(with: "Error: \(error.localizedDescription)")
            }
        }
    }
    
    private func startUnify() {
        // Make sure phone number is present and valid
        guard let phoneNumber = phoneNumberTextField.text,
              !phoneNumber.isEmpty,
              phoneNumber.count > 9
        else {
            self.updateResultLabel(with: "Please enter a valid phone number.")
            return
        }
        
        // Warn the user authentication process has started
        self.showLoading(true)
        self.updateResultLabel(with: "Authenticating...")

        DataService.shared.unify(
            phoneNumber: phoneNumber
        ) { result in
            
            switch result {
                
            case .success(let result):
                self.updateResultLabel(with: "Starting Prove Unify...")
                let authFinishStep = AuthFinishHandler(
                    correlationId: result.correlationId,
                    onResult: self.onResult)
                let otpStartStep = OtpStartHandler(presentingViewController: self)
                let otpFinishStep = OtpFinishHandler(presentingViewController: self)
                self.proveAuthInstance = ProveAuth.builder(authFinish: authFinishStep)
                    .withMobileAuthTestMode()
                    .withOtpFallback(otpStart: otpStartStep, otpFinish: otpFinishStep)
                    .build()
                self.proveAuthInstance?.authenticate(authToken: result.authToken) { [weak self] error in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        if let failureReason = error.failureReason {
                            self.showLoading(false)
                            self.updateResultLabel(with: "Error: \(failureReason)")
                        }
                    }
                }

            // Warn user the unify authentication process failed
            case .failure(let error):
                self.showLoading(false)
                self.updateResultLabel(with: "Error: \(error.localizedDescription)")
            }
            
        }
    }
    
    private func showLoading(_ show: Bool) {
        DispatchQueue.main.async {
            if show {
                self.activityIndicator.startAnimating()
                self.resultLabel.text = "Authenticating..."
            } else {
                self.activityIndicator.stopAnimating()
            }
        }
    }
    
    private func updateResultLabel(with string: String) {
        DispatchQueue.main.async { self.resultLabel.text = string }
    }
    
    private func setUpPhoneAutofillTextField() {
        phoneNumberTextField.textContentType = .telephoneNumber
        phoneNumberTextField.keyboardType = .phonePad
    }
    
    private lazy var onResult: (String) -> Void = { [weak self] message in
        guard let self = self else { return }
        self.updateResultLabel(with: message)
    }
    
}
