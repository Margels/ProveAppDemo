//
//  Constants.swift
//  ProveAppDemo
//
//  Created by Margels on 25/06/25.
//

import Foundation

class DataService {
    
    let clientId = "<CLIENT_ID>"
    let clientSecret = "<CLIENT_SECRET>"
    
    static var shared = DataService()
    
    // MARK: - Get OAuth2 Bearer Token
    func getBearerToken(
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        
        // Validate URL and return error upon failure
        guard let url = URL(string: "https://platform.uat.proveapis.com/token") else {
            completion(.failure(NSError(domain: "InvalidURL", code: 0)))
            return
        }
        
        // Set up request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Set up body params
        let bodyParams = "grant_type=client_credentials&client_id=\(clientId)&client_secret=\(clientSecret)"
        request.httpBody = bodyParams.data(using: .utf8)
        
        // Start data task
        URLSession.shared.dataTask(with: request) { data, response, error in
            
            // If data task fails, return failure
            if let error = error {
                completion(.failure(error))
                return
            }
            
            // If data is absent, return failure
            guard let data = data else {
                completion(.failure(NSError(domain: "NoData", code: 0)))
                return
            }
            
            // Parse response
            do {
                let tokenResponse = try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
                completion(.success(tokenResponse.access_token))
            } catch {
                completion(.failure(error))
            }
            
        }.resume()
    }
    
    // MARK: - /v3/start
    func startAuthentication(
        bearerToken: String,
        phoneNumber: String,
        completion: @escaping (Result<String, Error>
        ) -> Void) {
        
        // Validate URL and return error upon failure
        guard let url = URL(string: "https://platform.uat.proveapis.com/v3/start") else {
            completion(.failure(NSError(domain: "InvalidURL", code: 0)))
            return
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Set up body params
        let bodyDict = [
            "phoneNumber": phoneNumber,
            "flowType": "mobile",
            "possessionType": "mobile",
            "clientRequestId": UUID().uuidString
        ]
        
        // Transform body params to JSON
        do {
            let bodyData = try JSONSerialization.data(withJSONObject: bodyDict, options: [])
            request.httpBody = bodyData
        } catch {
            completion(.failure(error))
            return
        }
        
        // Start data task
        URLSession.shared.dataTask(with: request) { data, response, error in
            
            // If data task fails, return failure
            if let error = error {
                completion(.failure(error))
                return
            }
            
            // If data is absent, return failure
            guard let data = data else {
                completion(.failure(NSError(domain: "NoData", code: 0)))
                return
            }
            
            // Parse response
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let authToken = json["authToken"] as? String {
                    
                    // Perform next step if needed or return auth token
                    if let correlationId = json["correlationId"] as? String,
                        let nextStep = json["next"] as? [String: String],
                        let path = nextStep.first?.value {
                        self.nextStepProveFlow(bearerToken: bearerToken, correlationId: correlationId, path: path) { result in
                            switch result {
                            case .success(let success):
                                completion(.success(authToken))
                            case .failure(let error):
                                completion(.failure(error))
                            }
                        }
                    } else {
                        completion(.success(authToken))
                    }
                }
            } catch {
                completion(.failure(error))
            }
            
        }.resume()
    }
    
    // MARK: - Call next step if needed
    func nextStepProveFlow(
        bearerToken: String,
        correlationId: String,
        path: String,
        completion: @escaping (Result<ValidateResponse, Error>) -> Void
    ) {

        // Validate URL and return error upon failure
        guard let url = URL(string: "https://platform.uat.proveapis.com\(path)") else { return }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Set up body params
        let bodyDict: [String: String] = [
            "correlationId": correlationId,
            "flowType": "mobile",
            "possessionType": "mobile",
            "clientRequestId": UUID().uuidString
        ]

        // Transform body params to JSON
        do {
            let bodyData = try JSONSerialization.data(withJSONObject: bodyDict, options: [])
            request.httpBody = bodyData
        } catch {
            completion(.failure(error))
            return
        }

        // Start data task
        URLSession.shared.dataTask(with: request) { data, response, error in
            
            // If data task fails, return failure
            if let error = error {
                completion(.failure(error))
                return
            }
            
            // If data is absent, return failure
            guard let data = data else {
                completion(.failure(NSError(domain: "NoData", code: 0)))
                return
            }

            // Parse response
            do {
                let decoder = JSONDecoder()
                let validateResponse = try decoder.decode(ValidateResponse.self, from: data)
                completion(.success(validateResponse))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    // MARK: - Authenticate chain calls
    func authenticate(phoneNumber: String, completion: @escaping (Result<String, Error>) -> Void) {
        getBearerToken { result in
            switch result {
            case .success(let bearerToken):
                self.startAuthentication(bearerToken: bearerToken, phoneNumber: phoneNumber, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    
    
    // MARK: - Call /v3/unify
    func startUnifyFlow(
        bearerToken: String,
        phoneNumber: String,
        completion: @escaping (Result<(authToken: String, correlationId: String), Error>) -> Void
    ) {
        
        // Validate URL and return error upon failure
        guard let url = URL(string: "https://platform.uat.proveapis.com/v3/unify") else {
            completion(.failure(NSError(domain: "InvalidURL", code: 0)))
            return
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Set up body params
        let bodyDict: [String: Any] = [
            "phoneNumber": phoneNumber,
            "flowType": "mobile",
            "possessionType": "mobile",
            "clientRequestId": UUID().uuidString
        ]

        // Transform body params to JSON
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: bodyDict)
        } catch {
            completion(.failure(error))
            return
        }

        // Start data task
        URLSession.shared.dataTask(with: request) { data, response, error in
            
            // If data task fails, return failure
            if let error = error {
                completion(.failure(error))
                return
            }
            
            // If data is absent, return failure
            guard let data = data else {
                completion(.failure(NSError(domain: "NoData", code: 0)))
                return
            }

            // Parse response
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let authToken = json["authToken"] as? String,
                   let correlationId = json["correlationId"] as? String {
                    completion(.success((authToken, correlationId)))
                } else {
                    completion(.failure(NSError(domain: "MissingFields", code: 0)))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: - Call /v3/unify-status
    func checkUnifyStatus(
        bearerToken: String,
        correlationId: String,
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        
        // Validate URL and return error upon failure
        guard let url = URL(string: "https://platform.uat.proveapis.com/v3/unify-status") else {
            completion(.failure(NSError(domain: "InvalidURL", code: 0)))
            return
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Set up body params
        let bodyDict = ["correlationId": correlationId]

        // Transform body params to JSON
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: bodyDict)
        } catch {
            completion(.failure(error))
            return
        }

        // Start data task
        URLSession.shared.dataTask(with: request) { data, response, error in
            
            // If data task fails, return failure
            if let error = error {
                completion(.failure(error))
                return
            }
            
            // If data is absent, return failure
            guard let data = data else {
                completion(.failure(NSError(domain: "NoData", code: 0)))
                return
            }

            // Parse response
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = json["success"] as? NSString {
                    completion(.success(success.boolValue))
                } else {
                    completion(.failure(NSError(domain: "InvalidResponse", code: 0)))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    
    // MARK: - Unify chain calls
    func unify(phoneNumber: String, completion: @escaping (Result<(authToken: String, correlationId: String), Error>) -> Void) {
        getBearerToken { result in
            switch result {
            case .success(let bearerToken):
                self.startUnifyFlow(bearerToken: bearerToken, phoneNumber: phoneNumber, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Unify status chain calls
    func checkUnifyStatus(correlationId: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        getBearerToken { result in
            switch result {
            case .success(let bearerToken):
                self.checkUnifyStatus(bearerToken: bearerToken, correlationId: correlationId, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    
}
