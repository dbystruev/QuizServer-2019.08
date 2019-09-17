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
    private var nextId = 0
    
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
        
        // Find maximum id and assign it to nextID
        Question.findAll { questions, error in
            let maxQuestionId = questions?.compactMap({ $0.id }).max() ?? -1
            
            Answer.findAll { answers, error in
                let maxAnswerId = answers?.compactMap({ $0.id }).max() ?? -1
                self.nextId = max(maxQuestionId, maxAnswerId) + 1
                print(#line, #function, "nextId =", self.nextId)
            }
        }
        
        // Endpoints
        initializeHealthRoutes(app: self)
        KituraOpenAPI.addEndpoints(to: router)
        
        // KituraCORS
        let options = Options(allowedOrigin: .all)
        let cors = CORS(options: options)
        
        // Setup Routes
        router.all("/*", middleware: cors)
        
        //        router.delete("/", handler: deleteAllHandler)
        //        router.delete("/", handler: deleteOneHandler)
        //        router.get("/", handler: getAllHandler)
        //        router.get("/", handler: getOneHandler)
        //        router.patch("/", handler: updateHandler)
        //        router.post("/", handler: storeHandler)
        
        router.get("/answers", handler: getAllAnswersHandler)
        router.get("/answers", handler: getOneAnswerHandler)
        router.delete("/answers", handler: deleteOneAnswerHandler)
        router.patch("/answers", handler: updateAnswerHandler)
        router.post("/answers", handler: storeAnswerHandler)
        
        router.get("/questions", handler: getAllQuestionsHandler)
        router.get("/questions", handler: getOneQuestionHandler)
        router.post("/questions", handler: storeQuestionHandler)
    }
    
    // MARK: - Answer Handlers
    func getAllAnswersHandler(completion: @escaping ([Answer]?, RequestError?) -> Void) {
        Answer.findAll(completion)
    }
    
    func getOneAnswerHandler(id: Int, completion: @escaping (Answer?, RequestError?) -> Void) {
        Answer.find(id: id, completion)
    }
    
    func storeAnswerHandler(answer: Answer, completion: @escaping (Answer?, RequestError?) -> Void) {
        // check that text and type are not empty
        let answerId = nextId
        
        guard
            let text = answer.text,
            !text.isEmpty,
            answer.type != nil
            else {
                return completion(nil, .badRequest)
        }
        
        // store answer
        var answer = answer
        answer.id = answerId
        nextId += 1
        return answer.save(completion)
    }
    
    func deleteOneAnswerHandler(id: Int, completion: @escaping (RequestError?) -> Void) {
        Answer.delete(id: id, completion)
    }
    
    func updateAnswerHandler(id: Int, new: Answer, completion: @escaping (Answer?, RequestError?) -> Void) {
        
        Answer.find(id: id) { current, error in
            guard error == nil else {
                return completion(nil, error)
            }
            
            guard var current = current else {
                return completion(nil, .notFound)
            }
            
            guard id == current.id else {
                return completion(nil, .internalServerError)
            }
            
            current.text = new.text ?? current.text
            current.type = new.type ?? current.type
            current.questionId = new.questionId ?? current.questionId
            
            current.update(id: id, completion)
        }
    }
    
    // MARK: - Question Handlers
    func getAllQuestionsHandler(completion: @escaping ([Question]?, RequestError?) -> Void) {
        Question.findAll(completion)
    }
    
    func getOneQuestionHandler(id: Int, completion: @escaping (Question?, RequestError?) -> Void) {
        Question.find(id: id, completion)
    }
    
    func storeQuestionHandler(question: Question, completion: @escaping (Question?, RequestError?) -> Void) {
        let questionId = nextId
        
        guard
            let text = question.text,
            !text.isEmpty,
            question.type != nil
            else {
                return completion(nil, .badRequest)
        }
        
        // store question
        var question = question
        question.id = questionId
        nextId += 1
        
        return question.save(completion)
    }
    
    // MARK: - DELETE Handlers
    //    func deleteAllHandler(completion: @escaping (RequestError?) -> Void) {
    //        ToDo.deleteAll(completion)
    //    }
    //
    //    func deleteOneHandler(id: Int, completion: @escaping (RequestError?) -> Void) {
    //        ToDo.delete(id: id, completion)
    //    }
    //
    //    // MARK: - PATCH Handlers
    //    func updateHandler(id: Int, new: ToDo, completion: @escaping (ToDo?, RequestError?) -> Void) {
    //
    //        ToDo.find(id: id) { current, error in
    //            guard error == nil else {
    //                return completion(nil, error)
    //            }
    //
    //            guard var current = current else {
    //                return completion(nil, .notFound)
    //            }
    //
    //            guard id == current.id else {
    //                return completion(nil, .internalServerError)
    //            }
    //
    //            current.user = new.user ?? current.user
    //            current.order = new.order ?? current.order
    //            current.title = new.title ?? current.title
    //            current.completed = new.completed ?? current.completed
    //
    //            current.update(id: id, completion)
    //        }
    //    }
    //
    //    // MARK: - POST Handlers
    //    func storeHandler(todo: ToDo, completion: @escaping (ToDo?, RequestError?) -> Void) {
    //        var todo = todo
    //        if todo.completed == nil {
    //            todo.completed = false
    //        }
    //        todo.id = nextId
    //        todo.url = "http://localhost:8080/\(nextId)"
    //        nextId += 1
    //        todo.save(completion)
    //    }
    
    // MARK: - Running
    public func run() throws {
        try postInit()
        Kitura.addHTTPServer(onPort: cloudEnv.port, with: router)
        Kitura.run()
    }
}

