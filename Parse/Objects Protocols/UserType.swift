import Foundation

private var currentUser: Any?
private var currentSessionToken: String?

public protocol UserType: ObjectType {
    var username: String? { get set }
    var email: String? { get set }
    var password: String? { get set }
}

public extension UserType {
    var sessionToken: String? {
        if let currentUser = currentUser as? Self,
            currentUser.objectId != nil && self.objectId != nil &&
            currentUser.objectId == self.objectId {
            return currentSessionToken
        }
        return nil
    }
}

public extension UserType {
    public typealias UserTypeCallback = (Result<Self>)->()

    static var current: Self? {
        return currentUser as? Self
    }

    static func login(username: String, password: String, callback: UserTypeCallback? = nil) -> Cancellable {
        return loginCommand(username: username, password: password).execute(callback)
    }

    static func signup(username: String, password: String, callback: UserTypeCallback? = nil) -> Cancellable {
        return signupCommand(username: username, password: password).execute(callback)
    }

    static func logout(callback: ((Result<()>)->())?) {
        _ = RESTCommand<NoBody, Void>(method: .POST, path: "/users/logout", body: nil, mapper: { (data) -> Void in
            currentUser = nil
            currentSessionToken = nil
        }).execute(callback)
    }

    func signup(callback: UserTypeCallback? = nil) -> Cancellable {
        return RESTCommand(method: .POST, path: "/users", body: self, mapper: { (data) -> Self in
            let response = try getDecoder().decode(SignupResponse.self, from: data)
            print(response)
            var user = try getDecoder().decode(Self.self, from: data)
            print(user)
            user.updatedAt = response.updatedAt

            // Set the current user
            currentUser = user
            currentSessionToken = response.sessionToken
            return user
        }).execute(callback)
    }
}

private extension UserType {
    private static func loginCommand(username: String, password: String, callback: UserTypeCallback? = nil) -> RESTCommand<NoBody, Self> {
        let params = [
            "username": username,
            "password": password
        ]
        return RESTCommand<NoBody, Self>(method: .GET, path: "/login", params: params, mapper: { (data) -> Self in
            let r = try getDecoder().decode(Self.self, from: data)
            currentUser = r
            return r
        }).execute(callback)
    }

    private static func signupCommand(username: String, password: String) -> RESTCommand<SignupBody, Self> {
        let body = SignupBody(username: username, password: password)
        return RESTCommand(method: .POST, path: "/users", body: body, mapper: { (data) -> Self in
            let response = try getDecoder().decode(SignupResponse.self, from: data)
            var user = try getDecoder().decode(Self.self, from: data)
            user.username = username
            user.password = password
            user.updatedAt = response.updatedAt

            // Set the current user
            currentUser = user
            currentSessionToken = response.sessionToken
            return user
        })
    }
}

public struct SignupBody: Codable {
    let username: String
    let password: String
}

private struct SignupResponse: Codable {
    let createdAt: Date
    let objectId: String
    let sessionToken: String
    var updatedAt: Date {
        return createdAt
    }
}
