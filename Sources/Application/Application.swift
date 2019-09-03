import Dispatch
import Foundation
import Kitura
import LoggerAPI
import Configuration
import CloudEnvironment
import KituraContracts
import Health
import KituraOpenAPI
import KituraCORS
import SwiftKueryORM
import SwiftKueryPostgreSQL

public let projectPath = ConfigurationManager.BasePath.project.path
public let health = Health()

public class App {
    // MARK: - Stored Variables
    private var nextId = 10
    
    // MARK: - Constants
    let router = Router()
    let cloudEnv = CloudEnv()

    // MARK: - Initialization
    public init() throws {
        // Run the metrics initializer
        initializeMetrics(router: router)
    }

    func postInit() throws {
        // Database setup
        Persistence.setUp()
        
        do {
            try Answer.createTableSync()
        } catch let error {
            print(#line, #function, "WARNING: Table Answers already exists. \(error.localizedDescription)")
        }
        
        do {
            try Question.createTableSync()
        } catch let error {
            print(#line, #function, "WARNING: Table Questions already exists. \(error.localizedDescription)")
        }
        
        // TODO: Find maximum id and assign it to nextID
        
        // Endpoints
        initializeHealthRoutes(app: self)
        KituraOpenAPI.addEndpoints(to: router)
        
        // KituraCORS
        let options = Options(allowedOrigin: .all)
        let cors = CORS(options: options)
        
        // Setup Routes
        router.all("/*", middleware: cors)
        
        router.get("/questions", handler: getAllQuestionsHandler)
        router.get("/questions", handler: getOneQuestionHandler)
        router.post("/questions", handler: storeQuestionHandler)
        
        router.delete("/", handler: deleteAllHandler)
        router.delete("/", handler: deleteOneHandler)
        router.get("/", handler: getAllHandler)
        router.get("/", handler: getOneHandler)
        router.patch("/", handler: updateHandler)
        router.post("/", handler: storeHandler)
    }
    
    // MARK: - Question Handlers
    func getAllQuestionsHandler(completion: @escaping ([Question]?, RequestError?) -> Void) {
        Question.findAll(completion)
    }
    
    func getOneQuestionHandler(id: Int, completion: @escaping (Question?, RequestError?) -> Void) {
        Question.find(id: id, completion)
    }
    
    func storeQuestionHandler(question: Question, completion: @escaping (Question?, RequestError?) -> Void) {
        guard
            let text = question.text,
            !text.isEmpty,
            question.type != nil,
            let answerId = question.answerId
        else {
            return completion(nil, .badRequest)
        }
        // TODO: use answerId for Question.find(id: id, completion)
        Answer.find(id: answerId) { answer, error in
            guard answer != nil else {
                return completion(nil, .notFound)
            }
            var question = question
            question.id = self.nextId
            self.nextId += 1
            return question.save(completion)
            
        }
    }

    // MARK: - DELETE Handlers
    func deleteAllHandler(completion: @escaping (RequestError?) -> Void) {
        ToDo.deleteAll(completion)
    }
    
    func deleteOneHandler(id: Int, completion: @escaping (RequestError?) -> Void) {
        ToDo.delete(id: id, completion)
    }

    // MARK: - GET Handlers
    func getAllHandler(completion: @escaping ([ToDo]?, RequestError?) -> Void) {
        ToDo.findAll(completion)
    }
    
    func getOneHandler(id: Int, completion: @escaping (ToDo?, RequestError?) -> Void) {
        ToDo.find(id: id, completion)
    }
    
    // MARK: - PATCH Handlers
    func updateHandler(id: Int, new: ToDo, completion: @escaping (ToDo?, RequestError?) -> Void) {
        
        ToDo.find(id: id) { current, error in
            guard error == nil else {
                return completion(nil, error)
            }
            
            guard var current = current else {
                return completion(nil, .notFound)
            }
            
            guard id == current.id else {
                return completion(nil, .internalServerError)
            }
            
            current.user = new.user ?? current.user
            current.order = new.order ?? current.order
            current.title = new.title ?? current.title
            current.completed = new.completed ?? current.completed
            
            current.update(id: id, completion)
        }
    }

    // MARK: - POST Handlers
    func storeHandler(todo: ToDo, completion: @escaping (ToDo?, RequestError?) -> Void) {
        var todo = todo
        if todo.completed == nil {
            todo.completed = false
        }
        todo.id = nextId
        todo.url = "http://localhost:8080/\(nextId)"
        nextId += 1
        todo.save(completion)
    }

    // MARK: - Running
    public func run() throws {
        try postInit()
        Kitura.addHTTPServer(onPort: cloudEnv.port, with: router)
        Kitura.run()
    }
}

