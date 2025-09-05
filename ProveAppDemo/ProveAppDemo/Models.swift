//
//  Models.swift
//  ProveAppDemo
//
//  Created by Margels on 25/06/25.
//

import ProveAuth
import Foundation
import UIKit

class AuthFinishHandler: ProveAuthFinishStep {

    let correlationId: String?
    let onResult: (String) -> Void

    init(correlationId: String? = nil, onResult: @escaping (String) -> Void) {
        self.correlationId = correlationId
        self.onResult = onResult
    }

    func execute(authId: String) {
        guard let correlationId = correlationId else { self.onResult("Authentication failed ❌"); return }
        DataService.shared.checkUnifyStatus(correlationId: correlationId) { result in
            switch result {
            case .success(let success):
                self.onResult(success ? "Authentication succeeded ✅" : "Authentication failed ❌")
            case .failure(let error):
                self.onResult("Authentication failed ❌ \(error.localizedDescription)")
            }
        }
    }
}

struct ValidateResponse: Codable {
    let success: Bool
    let message: String?
    // Add more fields as per your API response spec
}

class OtpStartHandler: OtpStartStep {
    
    // We need to keep the callback for when user submits or cancels
        var callback: OtpStartStepCallback?
        
        // View controller to present UI from
        private weak var presentingVC: UIViewController?
        
        init(presentingViewController: UIViewController) {
            self.presentingVC = presentingViewController
        }
        
        func execute(phoneNumberNeeded: Bool, phoneValidationError: ProveAuthError?, callback: OtpStartStepCallback) {
            self.callback = callback
            
            DispatchQueue.main.async {
                if phoneNumberNeeded {
                    // Show an alert or custom UI to ask for phone number input
                    self.askForPhoneNumber(validationError: phoneValidationError)
                } else {
                    // No phone number needed, just confirm to send SMS
                    self.confirmSendSMS()
                }
            }
        }
        
        private func askForPhoneNumber(validationError: ProveAuthError?) {
            guard let vc = presentingVC else {
                callback?.onError()
                return
            }
            
            let alert = UIAlertController(title: "Enter Phone Number", message: validationError != nil ? "Invalid phone number, please try again." : nil, preferredStyle: .alert)
            alert.addTextField { textField in
                textField.placeholder = "+1XXXXXXXXXX"
                textField.keyboardType = .phonePad
            }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                self.callback?.onError()
            })
            alert.addAction(UIAlertAction(title: "Send OTP", style: .default) { _ in
                let phoneNumber = alert.textFields?.first?.text
                if let phoneNumber = phoneNumber, !phoneNumber.isEmpty {
                    let otpStartInput = OtpStartInput(phoneNumber: phoneNumber)
                    self.callback?.onSuccess(input: otpStartInput)
                } else {
                    // No phone number entered, consider as error or retry
                    self.callback?.onError()
                }
            })
            
            vc.present(alert, animated: true)
        }
        
        private func confirmSendSMS() {
            guard let vc = presentingVC else {
                callback?.onError()
                return
            }
            let alert = UIAlertController(title: "Confirm", message: "Send SMS OTP to your phone?", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                self.callback?.onError()
            })
            alert.addAction(UIAlertAction(title: "Yes", style: .default) { _ in
                // No phone number to input, just confirm send
                self.callback?.onSuccess(input: nil)
            })
            vc.present(alert, animated: true)
        }
}

class OtpFinishHandler: OtpFinishStep {
    
    private var callback: OtpFinishStepCallback?
        private weak var presentingVC: UIViewController?
        
        init(presentingViewController: UIViewController) {
            self.presentingVC = presentingViewController
        }
        
        func execute(otpError: ProveAuthError?, callback: OtpFinishStepCallback) {
            self.callback = callback
            
            DispatchQueue.main.async {
                self.askForOtp(validationError: otpError)
            }
        }
        
        private func askForOtp(validationError: ProveAuthError?) {
            guard let vc = presentingVC else {
                callback?.onError()
                return
            }
            
            let alert = UIAlertController(title: "Enter OTP", message: validationError != nil ? "Invalid OTP, please try again." : "Enter the OTP sent to your phone", preferredStyle: .alert)
            alert.addTextField { textField in
                textField.placeholder = "OTP"
                textField.keyboardType = .numberPad
            }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                self.callback?.onError()
            })
            alert.addAction(UIAlertAction(title: "Submit", style: .default) { _ in
                if let otp = alert.textFields?.first?.text, !otp.isEmpty {
                    let otpFinishInput = OtpFinishInput(otp: otp)
                    self.callback?.onSuccess(input: otpFinishInput)
                } else {
                    self.callback?.onError()
                }
            })
            
            vc.present(alert, animated: true)
        }
}

struct OAuthTokenResponse: Codable {
    let access_token: String
    let token_type: String
    let expires_in: Int
}
