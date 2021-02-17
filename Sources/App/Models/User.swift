import Fluent
import Vapor

final class User: Model, Content {
    static let schema = "users"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "email")
    var email: String

    @Field(key: "password_hash")
    var passwordHash: String

    @Field(key: "first_name")
    var firstName: String

    @Field(key: "last_name")
    var lastName: String

    @Field(key: "default_name")
    var defaultName: String

    @Field(key: "meetings")
    var meetings: [String]

    init() { }

    init(id: UUID? = nil, name: String, email: String, passwordHash: String, firstName: String, lastName:String, meetings: [String]) {
        self.id = id
        self.defaultName = name
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.passwordHash = passwordHash
        self.meetings = meetings
    }
}


extension User {
    struct Migration: Fluent.Migration {
        var name: String { "CreateUser" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema("users")
                .id()
                .field("email", .string, .required)
                .field("password_hash", .string, .required)
                .field("first_name", .string, .required)
                .field("last_name", .string, .required)
                .field("default_name", .string, .required)
                .field("meetings", .array)
                .unique(on: "email")
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema("users").delete()
        }
    }
}

extension User:Validatable{
    static func validations(_ validations: inout Validations) {
        validations.add("defaultName", as:String.self, is:!.empty)
        validations.add("email",as:String.self, is: !.empty && .email)
        validations.add("passwordHash", as:String.self, is: .count(8...))
        validations.add("firstName", as:String.self, is: !.empty)
        validations.add("lastName", as:String.self, is: !.empty)
        validations.add("meetings", as:[String].self)
    }
}

extension User: ModelAuthenticatable {
    static let usernameKey = \User.$email
    static let passwordHashKey = \User.$passwordHash

    func verify(password: String) throws -> Bool {
        try Bcrypt.verify(password, created: self.passwordHash)
    }
}

