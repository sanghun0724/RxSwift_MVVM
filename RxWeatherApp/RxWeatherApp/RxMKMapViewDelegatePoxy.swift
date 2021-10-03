//
//  RxMKMapViewDelegatePoxy.swift
//  RxWeatherApp
//
//  Created by sangheon on 2021/10/04.
//

import Foundation
import RxSwift
import RxCocoa
import MapKit

//DelegateProxy객체는 수신된 모든 데이터를 전용 obseravable로 표시할 가짜 delegate 객체를 만들어냄
//위놈으로 연결하는거임
class RxMkMapViewDelegateProxy:DelegateProxy<MKMapView,MKMapViewDelegate>,DelegateProxyType
                               ,MKMapViewDelegate {
    static func registerKnownImplementations() {
        self.register { (mapView) -> RxMkMapViewDelegateProxy in
            RxMkMapViewDelegateProxy(parentObject: mapView, delegateProxy: self)
        }
    }
    
    static func currentDelegate(for object: MKMapView) -> MKMapViewDelegate? {
        return object.delegate
    }
    
    static func setCurrentDelegate(_ delegate: MKMapViewDelegate?, to object: MKMapView) {
        object.delegate = delegate
    }
}

extension Reactive where Base: MKMapView {
    var delegate: DelegateProxy<MKMapView,MKMapViewDelegate> {
        return RxMkMapViewDelegateProxy.proxy(for: self.base)
    }
    var regionDidChangeAnimated:Observable<Bool> {
        return delegate.methodInvoked(#selector(MKMapViewDelegate.mapView(_:regionDidChangeAnimated:))).map({
            (parameters) in
            return parameters[1] as? Bool ?? false
        }) // regionDidChange:Bool (해당함수 두번째 파라메터)를 가지고  Observable<Bool> type을 반환
    }
    
    var didUpdate:Observable<CLLocationCoordinate2D> {
        return delegate.methodInvoked(#selector(MKMapViewDelegate.mapView(_:didUpdate:))).map { (parameters)  in
            return (parameters[1] as? MKUserLocation)?.coordinate ?? CLLocationCoordinate2D.init(latitude: 0, longitude: 0)
        } //좌표 observable 반환~
    }
}