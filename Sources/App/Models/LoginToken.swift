class LoginToken{
    var id:String = ""
    var user:User = User()
    init(){}
    init(id:String, user:User){
        self.id = id
        self.user = user
    }
}