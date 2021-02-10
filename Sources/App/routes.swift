import Vapor

func routes(_ app: Application) throws {
    app.get { req in
        return "It works!"
    }

    app.get("hello") { req -> String in
        return "Hello, world!"
    }

    app.on(.GET,"hello","world"){ req -> String in
        return "Hello World"
    }

    app.get("hello",":name"){ req -> String in
        let name = req.parameters.get("name")!
        return "Hello \(name)"
    }

    // app.post(UserInfo.self, at:"userinfo") {  req, data -> String in
    //     return "Hello \(data.name)" 
    // }

    app.post("greeting") { req-> String in 
    let greeting = try req.content.decode(Greeting.self)
    print(greeting.hello) // "world"
    return "Hello World"
    }

    app.post("helloww") { req -> String in 
    let hello = try req.query.decode(Hello.self)
    return "Hello, \(hello.name ?? "Anonymous")"
    }
    app.get("helloww") { req -> String in 
    let hello = try req.query.decode(Hello.self)
    return "Hello, \(hello.name ?? "Anonymous")"
    }
    
}

struct UserInfo:Content {
    let name: String
}

struct Greeting: Content {
    var hello: String
}

struct Hello: Content {
    var name: String?
}