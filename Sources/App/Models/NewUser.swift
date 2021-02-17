import Fluent
import Vapor
import FluentSQL


final class NewUser:Model, Content{
    static let schema = "new_users"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "user")
    var user:User

    @Field(key: "token")
    var token:String

    @Timestamp(key: "created_at", on: .create, format: .unix)
    var createdAt: Date?

    @Field(key: "email")
    var email:String

    init(){}
}


extension NewUser {
    struct Migration: Fluent.Migration {
        var name: String { "CreateLoginUserFinal" }

        func prepare(on database: Database) -> EventLoopFuture<Void> {
            database.schema("new_users")
                .id()
                .field("user", .dictionary, .required)
                .field("token", .string, .required)
                .field("created_at", .datetime, .required)
                .field("email", .string, .required)
                .unique(on: "email")
                .create()
        }

        func revert(on database: Database) -> EventLoopFuture<Void> {
            database.schema("new_users").delete()
        }
    }
}

// Example middleware that capitalizes names.
