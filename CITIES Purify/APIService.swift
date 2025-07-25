import Foundation
import os

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

// TODO: waitsForConnectivity
// TODO: NSURLErrorNetworkConnectionLost (during transport)
class APIService {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: APIService.self)
    )
    
    // MARK: - Generic Request Helper (Data body version)
    private static func performRequest<T>(
        urlString: String,
        method: HTTPMethod = .get,
        body: Data? = nil,
        description: String? = nil,
        completion: @escaping (Result<T, Error>) -> Void,
        decoder: @escaping (Data) throws -> T
    ) {
        // 1. Check if the url is valid
        guard let url = URL(string: urlString) else {
            Self.logger.error("Invalid URL from string: \(urlString, privacy: .public)")
            completion(.failure(NSError(domain: "Invalid URL", code: -1, userInfo: nil)))
            return
        }
        
        // 2. Initiate URLRequest with the appropriate method, header, and body
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        
        // 3. Initiate URLSession
        URLSession.shared.dataTask(with: request) { data, response, error in
            // 3.1. Network error
            if let error = error {
                Self.logger.error("Network error for \(urlString, privacy: .public): \(error.localizedDescription, privacy: .public)")
                completion(.failure(error))
                return
            }
            
            // 3.2. Invalid HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                Self.logger.error("Invalid response for \(urlString, privacy: .public)")
                completion(.failure(NSError(domain: "Invalid response", code: -1, userInfo: nil)))
                return
            }
            
            // 3.3. Potentially parse server error, if exists
            if let data = data {
                do {
                    let jsonResult = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                    if let errorMessage = jsonResult?["error"] as? String {
                        Self.logger.error("HTTP error \(httpResponse.statusCode, privacy: .public) for \(urlString, privacy: .public), with server error message: \(errorMessage, privacy: .public)")
                        completion(.failure(NSError(domain: "HTTP Error", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                        return
                    }
                } catch {
                    Self.logger.error("HTTP error \(httpResponse.statusCode, privacy: .public) for \(urlString, privacy: .public), error parsing server error message.")
                }
            }
            
            // 3.4. Guard if not OK response
            guard (200...299).contains(httpResponse.statusCode), let data = data else {
                Self.logger.error("HTTP Error \(httpResponse.statusCode, privacy: .public) for \(urlString, privacy: .public)")
                completion(.failure(NSError(domain: "HTTP Error", code: httpResponse.statusCode, userInfo: nil)))
                return
            }
            
            // 3.4. Try decoding the response message
            do {
                let decodedResponse = try decoder(data)
                Self.logger.notice("Successfully decoded response for \(urlString, privacy: .public)\((description != nil) ? " (\(description!))" : "")")
                completion(.success(decodedResponse))
            } catch {
                Self.logger.error("Decoding error for \(urlString, privacy: .public)\((description != nil) ? " (\(description!))" : ""): \(error.localizedDescription, privacy: .public)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    // MARK: - Overload: Accept body as [String: Any]
    private static func performRequest<T>(
        urlString: String,
        method: HTTPMethod = .get,
        body: [String: Any],
        description: String? = nil,
        completion: @escaping (Result<T, Error>) -> Void,
        decoder: @escaping (Data) throws -> T
    ) {
        do {
            let data = try JSONSerialization.data(withJSONObject: body, options: [])
            performRequest(urlString: urlString, method: method, body: data, description: description, completion: completion, decoder: decoder)
        } catch {
            Self.logger.error("Error serializing JSON for \(urlString, privacy: .public): \(error.localizedDescription, privacy: .public)")
            completion(.failure(error))
        }
    }
    
    // MARK: - GET: Fetch Study Periods
    static func fetchStudyPeriods(completion: @escaping (Result<[StudyPeriod], Error>) -> Void) {
        performRequest(
            urlString: Config.periodsEndpoint,
            method: .get,
            body: nil,
            completion: completion,
            decoder: { data in
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .formatted(DateFormatter.backendDateFormatter)
                // Define a local wrapper type to decode the response structure.
                struct PeriodsResponse: Codable {
                    let message: String
                    let periods: [StudyPeriod]
                }
                let response = try decoder.decode(PeriodsResponse.self, from: data)
                return response.periods
            }
        )
    }
    
    // MARK: - GET: Fetch Daily Records
    static func fetchDailyRecords(pseudonym: String, completion: @escaping (Result<DailyRecordsResponse, Error>) -> Void) {
        performRequest(
            urlString: Config.dailyRecords(pseudonym: pseudonym),
            method: .get,
            body: nil,
            completion: completion,
            decoder: { data in
                return try JSONDecoder().decode(DailyRecordsResponse.self, from: data)
            }
        )
    }
    
    // MARK: - GET: Fetch Purifiers
    static func fetchPurifiers(completion: @escaping (Result<[Purifier], Error>) -> Void) {
        performRequest(
            urlString: Config.purifiersEndpoint(),
            method: .get,
            body: nil,
            completion: completion,
            decoder: { data in
                return try JSONDecoder().decode([Purifier].self, from: data)
            }
        )
    }
    
    // MARK: - GET: Fetch Purifier with ID
    static func fetchPurifierWithID(id: String, completion: @escaping (Result<Purifier, Error>) -> Void) {
        performRequest(
            urlString: Config.purifiersEndpoint(id: id),
            method: .get,
            body: nil,
            completion: completion,
            decoder: { data in
                return try JSONDecoder().decode(Purifier.self, from: data)
            }
        )
    }
    
    // MARK: - POST: Register Participant
    static func registerParticipant(
        pseudonym: String,
        periodId: Int,
        purifierId: String,
        notificationDeviceToken: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let body: [String: Any] = [
            "period_id": periodId,
            "purifier_id": purifierId,
            "notification_device_token": notificationDeviceToken
        ]
        
        performRequest(
            urlString: Config.participantEndpoint(pseudonym: pseudonym),
            method: .post,
            body: body,
            completion: { (result: Result<[String: Any], Error>) in
                switch result {
                case .success:
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            },
            decoder: { data in
                return (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] ?? [:]
            }
        )
    }
    
    // MARK: - PUT: Update Notification Device Token
    static func updateNotificationDeviceToken(
        pseudonym: String,
        notificationDeviceToken: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let body: [String: Any] = [
            "notification_device_token": notificationDeviceToken
        ]
        
        performRequest(
            urlString: Config.participantEndpoint(pseudonym: pseudonym),
            method: .put,
            body: body,
            completion: { (result: Result<[String: Any], Error>) in
                switch result {
                case .success:
                    completion(.success(()))
                case .failure(let error):
                    completion(.failure(error))
                }
            },
            decoder: { data in
                if let jsonResult = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let errorMessage = jsonResult["error"] as? String {
                    throw NSError(domain: "ServerError", code: 0, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                }
                return (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] ?? [:]
            }
        )
    }
    
    // MARK: - POST/DELETE: Modify Samples
    static func modifySamples<T: Encodable>(
        to urlString: String,
        with body: T,
        method: HTTPMethod,
        description: String,
        completion: @escaping (Bool) -> Void
    ) {
        do {
            // Encode the array directly since the backend expects an array.
            let data = try JSONEncoder().encode(body)
            performRequest(
                urlString: urlString,
                method: method,
                body: data,
                description: description,
                completion: { (result: Result<[String: Any], Error>) in
                    switch result {
                    case .success:
                        completion(true)
                    case .failure:
                        completion(false)
                    }
                },
                decoder: { data in
                    // Decode response if needed. Otherwise, return a dummy dictionary.
                    return (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] ?? [:]
                }
            )
        } catch {
            Self.logger.error("Failed to serialize JSON for modifySamples: \(error.localizedDescription)")
            completion(false)
        }
    }
    
    
    // MARK: - POST: Post Locations
    static func postLocations(
        pseudonym: String,
        locationTypeIntervals: [LocationTypeInterval],
        completion: @escaping (Bool) -> Void
    ) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601 // Crucial for Date handling
            let jsonData = try encoder.encode(locationTypeIntervals)
            // For this endpoint, we already have JSON data, so use the Data-version of performRequest.
            performRequest(
                urlString: Config.locationsEndpoint(pseudonym: pseudonym),
                method: .post,
                body: jsonData,
                completion: { (result: Result<[String: Any], Error>) in
                    switch result {
                    case .success:
                        completion(true)
                    case .failure:
                        completion(false)
                    }
                },
                decoder: { data in
                    return (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] ?? [:]
                }
            )
        } catch {
            Self.logger.error("Failed to encode locations: \(error.localizedDescription)")
            completion(false)
        }
    }
}
