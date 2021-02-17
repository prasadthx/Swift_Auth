import Vapor
import Smtp
import Foundation
import Fluent
import FluentSQLiteDriver


func routes(_ app: Application) throws {
   
   let sendEmail = { (user:User,token:String) -> Void in
        let encodedinit = ("\(user.email)" + "+" + "\(token)").data(using: .utf8)
        let encodedfinal = encodedinit?.base64EncodedString(options: Data.Base64EncodingOptions(rawValue: 0))
        
        print(encodedfinal)

        let email = Email(from: EmailAddress(address: "info.lifeline.health@protonmail.com", name: "Prasad Zore"),
                    to: [EmailAddress(address: "\(user.email)", name: "\(user.firstName)")],
                    subject: "Please verify your identity",
                    body: "Here is your link: \(encodedfinal)")
        app.smtp.send(email).map { result-> String in
            switch result {
            case .success:
                return "Email has been sent"
            case .failure(let error):
                return "Email has not been sent: \(error)"
            }  
        }
   }

   let tokenGenerator = {(length:Int) -> String in
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map{ _ in letters.randomElement()! })
   }

   let tokenDecoder = { (token:String?) -> String in
       guard let token_verify = token else {
            throw Abort(.badRequest)
        }
        guard let decodedData = Data(base64Encoded: token_verify) , let decodedString = String(data: decodedData, encoding: .utf8) else {
            throw Abort(.badRequest)
        }
        print("\(decodedString)")
        
        let components = decodedString.components(separatedBy:"+")
        let email = components[0]
        let token = components[1]

        print(email)
        print(token)
        return token
   }

   let uniqueEmailVerify = { (newuser: NewUser) -> EventLoopFuture<EventLoopFuture<String>> in
        User.query(on:app.db).filter("email", .equal, newuser.email).all().map{ list->EventLoopFuture<String> in
                return NewUser.query(on:app.db).filter("email", .equal, newuser.email).all().map{ value -> String in
                    guard list.isEmpty , value.isEmpty else{
                        return "Email is not unique"
                    }
                    newuser.create(on:app.db)
                    sendEmail(newuser.user, newuser.token)
                 //   newuser = NewUser()
                    return "Email sent successfully"
                }
            }
   }

   app.group("newUser"){ newUser in
        var newuser:NewUser = NewUser()
        
        newUser.post("users") { req->EventLoopFuture<EventLoopFuture<String>> in
            try User.validate(content:req)
            let create = try req.content.decode(User.self)
            var user:User = User()
            newuser.user = try User(
                name: create.defaultName,
                email: create.email,
                passwordHash: Bcrypt.hash(create.passwordHash),
                firstName:create.firstName,
                lastName:create.lastName,
                meetings:create.meetings
            )
            user = newuser.user

            newuser.email = create.email
            
            newuser.token = tokenGenerator(23)
            
            print("\(newuser.token)")
            
            return uniqueEmailVerify(newuser)
        }

    newUser.get("verify",":token") { req-> EventLoopFuture<String> in
        
        let token=try tokenDecoder(req.parameters.get("token"))
        
        return NewUser.query(on: app.db).filter("token", .equal, token).first().unwrap(or: Abort(.unauthorized)).map{ link->String in
            link.user.save(on:req.db)
            link.delete(force:true, on:req.db)
            return "New User added successfully"
        }
    }
}


let passwordProtected = app.grouped(User.authenticator())
passwordProtected.post("login") { req -> EventLoopFuture<UserToken> in
    let user = try req.auth.require(User.self)
    let token = try user.generateToken()
    return token.save(on: req.db)
        .map { token }
}

let tokenProtected = app.grouped(UserToken.authenticator())
tokenProtected.get("me") { req -> User in
    try req.auth.require(User.self)
}

tokenProtected.put("edituser"){ req -> EventLoopFuture<User> in
    var user = try req.auth.require(User.self)
    try User.validate(content:req)
    let email = user.email
    let newParameters = try req.content.decode(User.self)
    user.defaultName = newParameters.defaultName
    user.email = email
    user.passwordHash = try Bcrypt.hash(newParameters.passwordHash)
    user.firstName = newParameters.firstName
    user.lastName = newParameters.lastName
    user.meetings = newParameters.meetings
    return user.update(on: req.db).map{
        user
    }
}

tokenProtected.get("changeemail",":newemail"){ req->EventLoopFuture<EventLoopFuture<String>> in
    var user = try req.auth.require(User.self)
    try NewEmail.validate(content:req)
    let email = try req.content.decode(NewEmail.self)
    var newUser:NewUser = NewUser()
    var token = tokenGenerator(23)
    newUser.token = token
    newUser.user = user
    newUser.email = email.email
    newUser.user.email = email.email
    return uniqueEmailVerify(newUser)
}

app.get("verifyemail",":token"){ req -> EventLoopFuture<String> in
    let token=try tokenDecoder(req.parameters.get("token"))
    print(token)
    return NewUser.query(on: app.db).filter("token", .equal, token).first().map { user in
        guard let newuser = user else{
            return "Bad request"
        }
        newuser.user.update(on: app.db)
        newuser.delete(on: app.db)
        return "Email updated successfully"
    }
}  


app.get("forgotpassword",":email"){ req->EventLoopFuture<String> in
    let email = try req.parameters.get("email")
    return User.query(on: req.db).filter("email", .equal, email).first().map{ user in
        let token = tokenGenerator(23)
        if user==nil{
            return "Register yourself first"
        }
        else{
            var newUser:NewUser = NewUser()
            newUser.token = token
            newUser.user = user!
            newUser.email = email!
            newUser.save(on:req.db)
            sendEmail(user!, token)
            return "Emsil has been sent successfully"
        }
    }
}

app.post("newPassword",":token"){ req -> EventLoopFuture<String> in
    let token=try tokenDecoder(req.parameters.get("token"))
    let password = try req.content.decode(Password.self)
    let passwordhash = try Bcrypt.hash(password.password)
    print(token)
    return NewUser.query(on: app.db).filter("token", .equal, token).first().map { user in
        guard let newuser = user else{
            return "Bad request"
        }
        newuser.user.passwordHash = passwordhash
        newuser.user.update(on: app.db)
        newuser.delete(on: app.db)
        return "Password updated successfully"
    }
}

}    
    




    
struct Password:Content{
    var password:String
}

struct NewEmail: Content{
    var email : String
}

extension NewEmail:Validatable{
    static func validations(_ validations: inout Validations) {
        validations.add("email",as:String.self, is: !.empty && .email)
    }
}