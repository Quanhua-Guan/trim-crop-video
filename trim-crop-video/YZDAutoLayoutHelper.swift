//
//  YZDAutoLayout.swift
//  HiWidget
//
//  Created by yuyuan on 2022/9/9.
//

import Foundation
import UIKit

// MARK: - 自动布局方法封装

extension UIView {
    
    /// 获取自动布局辅助类实例
    /// 如果强引用该实例, 请注意循环引用问题
    var yzd: YZDAutoLayoutHelper {
        self.translatesAutoresizingMaskIntoConstraints = false
        return YZDAutoLayoutHelper(view: self)
    }
    
}

/// 自动布局辅助类
struct YZDAutoLayoutHelper {
    
    /// 需要自动布局的视图
    let v: UIView
    
    init(view: UIView) {
        v = view
    }
    
    func edges(equalTo secondView: UIView? = nil, inset: UIEdgeInsets = .zero, safeTop: Bool = false, safeLeft: Bool = false, safeBottom: Bool = false, safeRight: Bool = false) -> YZDAutoLayoutHelper {
        if let secondView = secondView ?? v.superview {
            v.leftAnchor.constraint(equalTo: safeLeft ? secondView.safeAreaLayoutGuide.leftAnchor : secondView.leftAnchor, constant: inset.left).isActive = true
            v.rightAnchor.constraint(equalTo: safeRight ? secondView.safeAreaLayoutGuide.rightAnchor : secondView.rightAnchor, constant: -inset.right).isActive = true
            v.topAnchor.constraint(equalTo: safeTop ? secondView.safeAreaLayoutGuide.topAnchor : secondView.topAnchor, constant: inset.top).isActive = true
            v.bottomAnchor.constraint(equalTo: safeBottom ? secondView.safeAreaLayoutGuide.bottomAnchor : secondView.bottomAnchor, constant: -inset.bottom).isActive = true
        }
        return self
    }
    
    func left(equalTo secondView: UIView? = nil, _ constant: Double = 0, safe: Bool = false) -> YZDAutoLayoutHelper {
        if let secondView = secondView ?? v.superview {
            v.leftAnchor.constraint(equalTo: safe ? secondView.safeAreaLayoutGuide.leftAnchor : secondView.leftAnchor, constant: constant).isActive = true
        }
        return self
    }
    
    func leftEqualTo(anchor: NSLayoutXAxisAnchor, _ constant: Double = 0) -> YZDAutoLayoutHelper {
        v.leftAnchor.constraint(equalTo: anchor, constant: constant).isActive = true
        return self
    }
    
    func right(equalTo secondView: UIView? = nil, _ constant: Double = 0, safe: Bool = false) -> YZDAutoLayoutHelper {
        if let secondView = secondView ?? v.superview {
            v.rightAnchor.constraint(equalTo: safe ? secondView.safeAreaLayoutGuide.rightAnchor : secondView.rightAnchor, constant: constant).isActive = true
        }
        return self
    }
    
    func rightEqualTo(anchor: NSLayoutXAxisAnchor, _ constant: Double = 0) -> YZDAutoLayoutHelper {
        v.rightAnchor.constraint(equalTo: anchor, constant: constant).isActive = true
        return self
    }
    
    func top(equalTo secondView: UIView? = nil, _ constant: Double = 0, safe: Bool = false) -> YZDAutoLayoutHelper {
        if let secondView = secondView ?? v.superview {
            v.topAnchor.constraint(equalTo: safe ? secondView.safeAreaLayoutGuide.topAnchor : secondView.topAnchor, constant: constant).isActive = true
        }
        return self
    }
    
    func topEqualTo(anchor: NSLayoutYAxisAnchor, _ constant: Double = 0) -> YZDAutoLayoutHelper {
        v.topAnchor.constraint(equalTo: anchor, constant: constant).isActive = true
        return self
    }
    
    func bottom(equalTo secondView: UIView? = nil, _ constant: Double = 0, safe: Bool = false) -> YZDAutoLayoutHelper {
        if let secondView = secondView ?? v.superview {
            v.bottomAnchor.constraint(equalTo: safe ? secondView.safeAreaLayoutGuide.bottomAnchor : secondView.bottomAnchor, constant: constant).isActive = true
        }
        return self
    }
    
    func bottomEqualTo(anchor: NSLayoutYAxisAnchor, _ constant: Double = 0) -> YZDAutoLayoutHelper {
        v.bottomAnchor.constraint(equalTo: anchor, constant: constant).isActive = true
        return self
    }
    
    func leading(equalTo secondView: UIView? = nil, _ constant: Double = 0, safe: Bool = false) -> YZDAutoLayoutHelper {
        if let secondView = secondView ?? v.superview {
            v.leadingAnchor.constraint(equalTo: safe ? secondView.safeAreaLayoutGuide.leadingAnchor : secondView.leadingAnchor, constant: constant).isActive = true
        }
        return self
    }
    
    func leadingEqualTo(anchor: NSLayoutXAxisAnchor, _ constant: Double = 0) -> YZDAutoLayoutHelper {
        v.leadingAnchor.constraint(equalTo: anchor, constant: constant).isActive = true
        return self
    }
    
    func leadingGreaterThanOrEqualTo(anchor: NSLayoutXAxisAnchor? = nil, _ constant: Double = 0) -> YZDAutoLayoutHelper {
        v.leadingAnchor.constraint(greaterThanOrEqualTo: anchor ?? v.superview!.leadingAnchor, constant: constant).isActive = true
        return self
    }
    
    func trailing(equalTo secondView: UIView? = nil, _ constant: Double = 0, safe: Bool = false) -> YZDAutoLayoutHelper {
        if let secondView = secondView ?? v.superview {
            v.trailingAnchor.constraint(equalTo: safe ? secondView.safeAreaLayoutGuide.trailingAnchor : secondView.trailingAnchor, constant: constant).isActive = true
        }
        return self
    }
    
    func trailingEqualTo(anchor: NSLayoutXAxisAnchor, _ constant: Double = 0) -> YZDAutoLayoutHelper {
        v.trailingAnchor.constraint(equalTo: anchor, constant: constant).isActive = true
        return self
    }
    
    func width(equalTo secondView: UIView? = nil, multiplier: Double = 1.0, _ constant: Double = 0, safe: Bool = false) -> YZDAutoLayoutHelper {
        if let secondView = secondView ?? v.superview {
            v.widthAnchor.constraint(equalTo: safe ? secondView.safeAreaLayoutGuide.widthAnchor : secondView.widthAnchor, multiplier: multiplier, constant: constant).isActive = true
        }
        return self
    }
    
    func widthEqualTo(anchor: NSLayoutDimension? = nil, multiplier: Double = 1.0, _ constant: Double = 0) -> YZDAutoLayoutHelper {
        if let anchor = anchor {
            v.widthAnchor.constraint(equalTo: anchor, multiplier: multiplier, constant: constant).isActive = true
        } else {
            v.widthAnchor.constraint(equalToConstant: constant).isActive = true
        }
        return self
    }
    
    func widthGreaterThenOrEqualTo(anchor: NSLayoutDimension? = nil, multiplier: Double = 1.0, _ constant: Double = 0) -> YZDAutoLayoutHelper {
        if let anchor = anchor {
            v.widthAnchor.constraint(greaterThanOrEqualTo: anchor, multiplier: multiplier, constant: constant).isActive = true
        } else {
            v.widthAnchor.constraint(greaterThanOrEqualToConstant: constant).isActive = true
        }
        return self
    }
    
    func widthLessThenOrEqualTo(anchor: NSLayoutDimension? = nil, multiplier: Double = 1.0, _ constant: Double = 0) -> YZDAutoLayoutHelper {
        if let anchor = anchor {
            v.widthAnchor.constraint(lessThanOrEqualTo: anchor, multiplier: multiplier, constant: constant).isActive = true
        } else {
            v.widthAnchor.constraint(lessThanOrEqualToConstant: constant).isActive = true
        }
        return self
    }
        
    func height(equalTo secondView: UIView? = nil, multiplier: Double = 1.0, _ constant: Double = 0, safe: Bool = false) -> YZDAutoLayoutHelper {
        if let secondView = secondView ?? v.superview {
            v.heightAnchor.constraint(equalTo: safe ? secondView.safeAreaLayoutGuide.heightAnchor : secondView.heightAnchor, multiplier: multiplier, constant: constant).isActive = true
        }
        return self
    }
    
    func heightEqualTo(anchor: NSLayoutDimension? = nil, multiplier: Double = 1.0, _ constant: Double = 0) -> YZDAutoLayoutHelper {
        if let anchor = anchor {
            v.heightAnchor.constraint(equalTo: anchor, multiplier: multiplier, constant: constant).isActive = true
        } else {
            v.heightAnchor.constraint(equalToConstant: constant).isActive = true
        }
        return self
    }
    
    func sizeEqualTo(_ width: Double, _ height: Double) -> YZDAutoLayoutHelper {
        v.widthAnchor.constraint(equalToConstant: width).isActive = true
        v.heightAnchor.constraint(equalToConstant: height).isActive = true
        return self
    }
    
    func centerX(equalTo secondView: UIView? = nil, _ constant: Double = 0, safe: Bool = false) -> YZDAutoLayoutHelper {
        if let secondView = secondView ?? v.superview {
            v.centerXAnchor.constraint(equalTo: safe ? secondView.safeAreaLayoutGuide.centerXAnchor : secondView.centerXAnchor, constant: constant).isActive = true
        }
        return self
    }
    
    func centerXEqualTo(anchor: NSLayoutXAxisAnchor, _ constant: Double = 0) -> YZDAutoLayoutHelper {
        v.centerXAnchor.constraint(equalTo: anchor, constant: constant).isActive = true
        return self
    }
    
    func centerY(equalTo secondView: UIView? = nil, _ constant: Double = 0, safe: Bool = false) -> YZDAutoLayoutHelper {
        if let secondView = secondView ?? v.superview {
            v.centerYAnchor.constraint(equalTo: safe ? secondView.safeAreaLayoutGuide.centerYAnchor : secondView.centerYAnchor, constant: constant).isActive = true
        }
        return self
    }
    
    func centerYEqualTo(anchor: NSLayoutYAxisAnchor, _ constant: Double = 0) -> YZDAutoLayoutHelper {
        v.centerYAnchor.constraint(equalTo: anchor, constant: constant).isActive = true
        return self
    }
    
    func center(equalTo secondView: UIView? = nil, offsetX: Double = 0, offsetY: Double = 0, safe: Bool = false) -> YZDAutoLayoutHelper {
        if let secondView = secondView ?? v.superview {
            v.centerXAnchor.constraint(equalTo: safe ? secondView.safeAreaLayoutGuide.centerXAnchor : secondView.centerXAnchor, constant: offsetX).isActive = true
            v.centerYAnchor.constraint(equalTo: safe ? secondView.safeAreaLayoutGuide.centerYAnchor : secondView.centerYAnchor, constant: offsetY).isActive = true
        }
        return self
    }
    
    
    /// 只能删除当前v,v和兄弟视图,v和父视图之间的约束
    /// 如果v有和别视图有约束关系,删除需要找到特定对象的视图进行约束删除 .
    func removeAllConstraint(){
        if let arr = v.superview?.constraints {
            var tempArr:[NSLayoutConstraint] = []
            for tempOne in arr {
                if let firstView = tempOne.firstItem as? UIView, firstView == v {
                    tempArr.append(tempOne)
                }
            }
            NSLayoutConstraint.deactivate(tempArr)
        }
        NSLayoutConstraint.deactivate(v.constraints)
    }
    
    /// 用于避免警告
    func end() {}
}
