import SwiftUI
import UIKit

/// A vertical paging container that properly coordinates with child ScrollViews.
struct VerticalPageView<Content: View>: UIViewControllerRepresentable {
    let pageCount: Int
    @Binding var currentPage: Int
    let content: (Int) -> Content

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pvc = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .vertical,
            options: [.interPageSpacing: 0]
        )
        pvc.dataSource = context.coordinator
        pvc.delegate = context.coordinator
        pvc.view.backgroundColor = .clear

        let initial = context.coordinator.makeHostingController(for: currentPage)
        pvc.setViewControllers([initial], direction: .forward, animated: false)

        // 冷启动首次上滑被"按住"感的根因：UIPageViewController 内部 UIScrollView
        // 默认 delaysContentTouches=true，会先等 ~150ms 判断「是否真的要 scroll」
        // 再 forward 触摸。app 第一次 interaction 时这个 delay 被感知最明显。
        // 关掉它，触摸立即 forward，纵滑换页瞬发。
        for subview in pvc.view.subviews {
            if let scrollView = subview as? UIScrollView {
                scrollView.delaysContentTouches = false
            }
        }

        return pvc
    }

    func updateUIViewController(_ pvc: UIPageViewController, context: Context) {
        // Update content of the currently displayed page
        if let current = pvc.viewControllers?.first as? UIHostingController<AnyView> {
            current.rootView = AnyView(content(context.coordinator.currentIndex))
        }

        let displayed = context.coordinator.currentIndex
        if currentPage != displayed {
            let direction: UIPageViewController.NavigationDirection = currentPage > displayed ? .forward : .reverse
            let vc = context.coordinator.makeHostingController(for: currentPage)
            pvc.setViewControllers([vc], direction: direction, animated: true)
            context.coordinator.currentIndex = currentPage
        }
    }

    class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        let parent: VerticalPageView
        var currentIndex: Int
        private var cachedControllers: [Int: UIHostingController<AnyView>] = [:]

        init(_ parent: VerticalPageView) {
            self.parent = parent
            self.currentIndex = parent.currentPage
            super.init()
            // 预缓存所有页面，避免首次切页时卡顿
            for i in 0..<parent.pageCount {
                let vc = UIHostingController(rootView: AnyView(parent.content(i)))
                vc.view.backgroundColor = .clear
                vc.view.tag = i
                cachedControllers[i] = vc
            }
        }

        func makeHostingController(for index: Int) -> UIHostingController<AnyView> {
            if let cached = cachedControllers[index] {
                cached.rootView = AnyView(parent.content(index))
                return cached
            }
            let vc = UIHostingController(rootView: AnyView(parent.content(index)))
            vc.view.backgroundColor = .clear
            vc.view.tag = index
            cachedControllers[index] = vc
            return vc
        }

        func pageViewController(_ pvc: UIPageViewController, viewControllerBefore vc: UIViewController) -> UIViewController? {
            let index = vc.view.tag
            guard index > 0 else { return nil }
            return makeHostingController(for: index - 1)
        }

        func pageViewController(_ pvc: UIPageViewController, viewControllerAfter vc: UIViewController) -> UIViewController? {
            let index = vc.view.tag
            guard index < parent.pageCount - 1 else { return nil }
            return makeHostingController(for: index + 1)
        }

        func pageViewController(_ pvc: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            guard completed,
                  let current = pvc.viewControllers?.first else { return }
            let index = current.view.tag
            currentIndex = index
            parent.currentPage = index
        }
    }
}
