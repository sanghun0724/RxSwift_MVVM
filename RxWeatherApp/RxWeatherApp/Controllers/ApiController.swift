//
//  ApiController.swift
//  RxWeatherApp
//
//  Created by sangheon on 2021/09/26.
//

import Foundation
import RxSwift
import RxCocoa
import SwiftyJSON
import CoreLocation
import MapKit

class ApiController {
    
    /// the shared instance
    static var shared = ApiController()
    
    let apiKey = BehaviorSubject(value: "ab4674ad07db87cfe9298be194bfd6b7")
    
    let baseURL = URL(string: "http://api.openweathermap.org/data/2.5")
    
//    init() {
//
//        }
    //MARK: = API Calls
    ///http://api.openweathermap.org/data/2.5/weather?q={city name}
    func currentWeather(city:String) -> Observable<Weather> {
        return buildRequest(pathComponent: "weather", params: [("q",city)])
            .map{ json in
                return Weather(cityName: json["name"].string ?? "UnKnown",
                               temperature: json["main"]["temp"].int ?? -1000,
                               humidity: json["main"]["humidity"].int ?? 0,
                               icon: iconNameToChar(icon: json["weather"][0]["icon"].string ?? "e"),
                               lat: json["coord"]["lat"].double ?? 0,
                               lon: json["coord"]["lon"].double ?? 0
                )
            }
    }
    func currentWeather(lat:CLLocationDegrees,lon:CLLocationDegrees) -> Observable<Weather> {
        return buildRequest(pathComponent: "weather", params: [("lat","\(lat)"),("lon","\(lon)")]).map
        { json in
            return Weather(
                cityName: json["name"].string ?? "Unknown",
                temperature: json["main"]["temp"].int ?? -1000,
                humidity: json["main"]["humidity"].int ?? 0,
                icon: iconNameToChar(icon: json["weather"][0]["icon"].string ?? "e"),
                lat: json["coord"]["lat"].double ?? 0,
                lon: json["coord"]["lon"].double ?? 0
            )
        }
    }
    
    func currentWeatherAround(lat: Double, lon: Double) -> Observable<[Weather]> {
      var weathers = [Observable<Weather>]()
      for i in -1...1 {
        for j in -1...1 {
          weathers.append(currentWeather(lat: lat + Double(i), lon: lon + Double(j)))
        }
      }

      return Observable.from(weathers)
        .merge()
        .toArray()
        .asObservable()
    }
    
    enum ApiError:Error {
        case cityNotFound
        case serverFailure
        case invalidKey
    }
    
    
    //MARK: Private Methods
    //buildRequest with RxCocoa
    private func buildRequest(method:String = "GET", pathComponent:String,params:[(String,String)]) -> Observable<JSON> {
        
        guard let url = baseURL?.appendingPathComponent(pathComponent) else {
            return Observable<JSON>.empty()
        }
        var request = URLRequest(url: url)
        let keyQueryItem = URLQueryItem(name: "appid", value: try? self.apiKey.value())
        let unitsQueryItem = URLQueryItem(name: "units", value: "metric")
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)!
        
        if method == "GET" {
            var queryItems = params.map {
                URLQueryItem(name: $0.0, value: $0.1)
            }
            queryItems.append(keyQueryItem)
            queryItems.append(unitsQueryItem)
            urlComponents.queryItems = queryItems
        } else { //POST
            urlComponents.queryItems = [keyQueryItem,unitsQueryItem]
            
            let jsonData = try! JSONSerialization.data(withJSONObject: params, options: .prettyPrinted)
            request.httpBody = jsonData
        }
        request.url = urlComponents.url!
        request.httpMethod = method
        
        request.setValue("aplication/json", forHTTPHeaderField: "Content-Type")
        
        let session = URLSession.shared
        print(request)
        
        return session.rx.response(request: request).map() { respone, data in
            if 200 ..< 300 ~= respone.statusCode {
                return try JSON(data: data)
            } else if respone.statusCode == 401 {
                throw ApiError.invalidKey
            } else if 400 ..< 500 ~= respone.statusCode {
                throw ApiError.cityNotFound
            } else {
                throw ApiError.serverFailure
            }
        }
        
    }
    
    struct Weather {
        let cityName: String
        let temperature:Int
        let humidity:Int
        let icon:String
        let lat:Double
        let lon:Double
        
        static let empty = Weather(cityName: "UnKnown",
                                   temperature: -1000,
                                   humidity: 0,
                                   icon: iconNameToChar(icon: "e"),
                                   lat: 0,
                                   lon: 0)
    
    var coordinate:CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
        func overlay() -> Overlay {
            let coordinates:[CLLocationCoordinate2D] = [
                CLLocationCoordinate2D(latitude: lat - 0.25, longitude: lon - 0.25),
                CLLocationCoordinate2D(latitude: lat + 0.25, longitude: lon + 0.25)
            ]
            let points = coordinates.map { MKMapPoint($0)}
            let rects = points.map { MKMapRect(origin: $0, size: MKMapSize(width: 0, height: 0))}
            let fittingRect = rects.reduce(MKMapRect.null)  { $0.union($1) }
            print("OverlayfuncWorking@@!!!!")
            print(coordinate)
            return Overlay(icon: icon, coordinate: coordinate, boundingMapRect: fittingRect)
        }
        
        public class Overlay: NSObject,MKOverlay {
            var coordinate: CLLocationCoordinate2D
            var boundingMapRect: MKMapRect
            let icon: String
            
            init(icon:String,coordinate:CLLocationCoordinate2D,boundingMapRect:MKMapRect) {
                self.coordinate = coordinate
                self.boundingMapRect = boundingMapRect
                self.icon = icon
            }
        }
        
        public class OverlayView:MKOverlayRenderer {
            var overlayIcon:String
            
            init(overlay:MKOverlay, overlayIcon:String) {
                self.overlayIcon = overlayIcon
                super.init(overlay: overlay)
            }
            
           
            public override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
                let imageReference = imageFromText(text: overlayIcon as NSString, font: UIFont(name: "Flaticon", size: 32.0)!).cgImage
                let theMapRect = overlay.boundingMapRect
                let theRect = rect(for: theMapRect)
                
                context.scaleBy(x: 1.0, y: -1.0)
                context.translateBy(x: 0.0, y: -theRect.size.height)
                context.draw(imageReference!,in: theRect)
            }
        }
        
      
        
        
}
}
    
    public func iconNameToChar(icon: String) -> String {
      switch icon {
      case "01d":
        return "\u{f11b}"
      case "01n":
        return "\u{f110}"
      case "02d":
        return "\u{f112}"
      case "02n":
        return "\u{f104}"
      case "03d", "03n":
        return "\u{f111}"
      case "04d", "04n":
        return "\u{f111}"
      case "09d", "09n":
        return "\u{f116}"
      case "10d", "10n":
        return "\u{f113}"
      case "11d", "11n":
        return "\u{f10d}"
      case "13d", "13n":
        return "\u{f119}"
      case "50d", "50n":
        return "\u{f10e}"
      default:
        return "E"
      }
}
    
fileprivate func imageFromText(text: NSString, font:UIFont) -> UIImage {
    let size = text.size(withAttributes: [NSAttributedString.Key.font: font])
    
    if (UIGraphicsBeginImageContextWithOptions != nil) {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
    } else {
        UIGraphicsBeginImageContext(size)
    }
    
    text.draw(at: CGPoint(x:0,y:0), withAttributes: [NSAttributedString.Key.font:font])
    
    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    
    return image ?? UIImage()
}
