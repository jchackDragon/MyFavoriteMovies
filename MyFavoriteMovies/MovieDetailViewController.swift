//
//  MovieDetailViewController.swift
//  MyFavoriteMovies
//
//  Created by Jarrod Parkes on 1/23/15.
//  Copyright (c) 2015 Udacity. All rights reserved.
//

import UIKit

// MARK: - MovieDetailViewController: UIViewController

class MovieDetailViewController: UIViewController {
    
    // MARK: Properties
    
    var appDelegate: AppDelegate!
    var isFavorite = false
    var movie: Movie?
    
    // MARK: Outlets
    
    @IBOutlet weak var posterImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var favoriteButton: UIButton!
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // get the app delegate
        appDelegate = UIApplication.shared.delegate as! AppDelegate
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        super.viewWillAppear(animated)
        
        if let movie = movie {
            
            // setting some defaults...
            posterImageView.image = UIImage(named: "film342.png")
            titleLabel.text = movie.title
            
            /* TASK A: Get favorite movies, then update the favorite buttons */
            /* 1A. Set the parameters */
            let methodParameters = [
                Constants.TMDBParameterKeys.ApiKey: Constants.TMDBParameterValues.ApiKey,
                Constants.TMDBParameterKeys.SessionID: appDelegate.sessionID!
            ]
            
            /* 2/3. Build the URL, Configure the request */
            let request = NSMutableURLRequest(url: appDelegate.tmdbURLFromParameters(methodParameters as [String:AnyObject], withPathExtension: "/account/\(appDelegate.userID!)/favorite/movies"))
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            
            /* 4A. Make the request */
            let task = appDelegate.sharedSession.dataTask(with: request as URLRequest) { (data, response, error) in
                
                /* GUARD: Was there an error? */
                guard (error == nil) else {
                    print("There was an error with your request: \(error)")
                    return
                }
                
                /* GUARD: Did we get a successful 2XX response? */
                guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else {
                    print("Your request returned a status code other than 2xx!")
                    return
                }
                
                /* GUARD: Was there any data returned? */
                guard let data = data else {
                    print("No data was returned by the request!")
                    return
                }
                
                /* 5A. Parse the data */
                let parsedResult: [String:AnyObject]!
                do {
                    parsedResult = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String:AnyObject]
                } catch {
                    print("Could not parse the data as JSON: '\(data)'")
                    return
                }
                
                /* GUARD: Did TheMovieDB return an error? */
                if let _ = parsedResult[Constants.TMDBResponseKeys.StatusCode] as? Int {
                    print("TheMovieDB returned an error. See the '\(Constants.TMDBResponseKeys.StatusCode)' and '\(Constants.TMDBResponseKeys.StatusMessage)' in \(parsedResult)")
                    return
                }
                
                /* GUARD: Is the "results" key in parsedResult? */
                guard let results = parsedResult[Constants.TMDBResponseKeys.Results] as? [[String:AnyObject]] else {
                    print("Cannot find key '\(Constants.TMDBResponseKeys.Results)' in \(parsedResult)")
                    return
                }
                
                /* 6A. Use the data! */
                let movies = Movie.moviesFromResults(results)
                self.isFavorite = false
                
                for movie in movies {
                    if movie.id == self.movie!.id {
                        self.isFavorite = true
                    }
                }
                
                performUIUpdatesOnMain {
                    self.favoriteButton.tintColor = (self.isFavorite) ? nil : .black
                }
            }
            
            /* 7A. Start the request */
            task.resume()
            
            /* TASK B: Get the poster image, then populate the image view */
            if let posterPath = movie.posterPath {
                
                /* 1B. Set the parameters */
                // There are none...
                
                /* 2B. Build the URL */
                let baseURL = URL(string: appDelegate.config.baseImageURLString)!
                let url = baseURL.appendingPathComponent("w342").appendingPathComponent(posterPath)
                
                /* 3B. Configure the request */
                let request = URLRequest(url: url)
                
                /* 4B. Make the request */
                let task = appDelegate.sharedSession.dataTask(with: request) { (data, response, error) in
                    
                    /* GUARD: Was there an error? */
                    guard (error == nil) else {
                        print("There was an error with your request: \(error)")
                        return
                    }
                    
                    /* GUARD: Did we get a successful 2XX response? */
                    guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else {
                        print("Your request returned a status code other than 2xx!")
                        return
                    }
                    
                    /* GUARD: Was there any data returned? */
                    guard let data = data else {
                        print("No data was returned by the request!")
                        return
                    }
                    
                    /* 5B. Parse the data */
                    // No need, the data is already raw image data.
                    
                    /* 6B. Use the data! */
                    if let image = UIImage(data: data) {
                        performUIUpdatesOnMain {
                            self.posterImageView!.image = image
                        }
                    } else {
                        print("Could not create image from \(data)")
                    }
                }
                
                /* 7B. Start the request */
                task.resume()
            }
        }
    }
    
    // MARK: Favorite Actions
    
    @IBAction func toggleFavorite(_ sender: AnyObject) {
        
         let shouldFavorite = !isFavorite
        
        /* TASK: Add movie as favorite, then update favorite buttons */
        /* 1. Set the parameters */
        let methodParameters = [Constants.TMDBParameterKeys.ApiKey:Constants.TMDBParameterValues.ApiKey,
                                Constants.TMDBParameterKeys.SessionID:appDelegate.sessionID!]
       
        let bodyParameters = ["media_type":"movie",
                              "media_id":self.movie?.id,
                              "favorite":shouldFavorite] as [String : Any]
        
        guard let postData = try? JSONSerialization.data(withJSONObject: bodyParameters) else{
            print("An error ocured wile parse the object to a json data: \(bodyParameters)")
            return
        }
        /* 2/3. Build the URL, Configure the request */
        let mRequest = NSMutableURLRequest(url: appDelegate.tmdbURLFromParameters(methodParameters as [String:AnyObject], withPathExtension: "/account/\(appDelegate.userID)/favorite"))
        mRequest.httpMethod = "POST"
        mRequest.addValue("application/json", forHTTPHeaderField: "Content-type")
        mRequest.addValue("application/json", forHTTPHeaderField: "Accept")
        mRequest.httpBody = postData
        /* 4. Make the request */
        let dataTask = appDelegate.sharedSession.dataTask(with: mRequest as URLRequest){(data,response,error) in
            
            print(mRequest.url!)
            
            guard (error == nil)else{
                print("The request has returned a error:\(error)")
                return
            }
            
            guard let stat = (response as? HTTPURLResponse)?.statusCode, stat >= 200 && stat <= 299 else{
                print("The request returned a status code other tham 2xx")
                return
            }
            
            guard let data = data else{
                print("No data returned in the request")
                return
            }
            
            /* 5. Parse the data */
            let parsedResult:[String:AnyObject]!
            do{
                parsedResult = try! JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String:AnyObject]
            }catch{
                print("Cannot parse to JSON the data:\(data)")
            }
            
            guard let statusCode = parsedResult[Constants.TMDBResponseKeys.StatusCode] as? Int else{
                print("Cannot find the key '\(Constants.TMDBResponseKeys.StatusCode)' in \(parsedResult)")
                return
            }
            /* 6. Use the data! Unrecognized*/
            if shouldFavorite && !(statusCode == 1 || statusCode == 12){
                print("Unrecognized '\(Constants.TMDBResponseKeys.StatusCode)' in \(parsedResult)")
                return
            }else if !shouldFavorite && statusCode != 13{
                print("Unrecognized '\(Constants.TMDBResponseKeys.StatusCode)' in \(parsedResult)")
                return
            }
            
            self.isFavorite = shouldFavorite
            
            performUIUpdatesOnMain {
                self.favoriteButton.tintColor = shouldFavorite ? nil: UIColor.black
            }
            
        }
        /* 7. Start the request */
        dataTask.resume()
        
      
    }
}
