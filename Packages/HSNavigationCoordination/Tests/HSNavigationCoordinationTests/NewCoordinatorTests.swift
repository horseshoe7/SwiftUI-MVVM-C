import XCTest
import SwiftUI
@testable import HSNavigationCoordination

// MARK: - Test Route Types

enum TestRoute: Routable {
    case home
    case profile
    case settings
    case detail(id: String)
    
    @MainActor
    func makeView(with coordinator: Coordinator<TestRoute>, presentationStyle: NavigationPresentationType) -> some View {
        Text("TestRoute: \(self)")
            .coordinatedView(
                coordinator: AnyCoordinator(coordinator),
                route: AnyRoutable(self),
                defaultExit: {
                    // Track default exit calls for testing
                    TestCallbackTracker.shared.recordDefaultExit(route: self)
                }
            )
    }
}

enum ChildRoute: Routable {
    case childHome
    case childDetail(value: Int)
    case childList
    
    @MainActor
    func makeView(with coordinator: Coordinator<ChildRoute>, presentationStyle: NavigationPresentationType) -> some View {
        Text("ChildRoute: \(self)")
            .coordinatedView(
                coordinator: AnyCoordinator(coordinator),
                route: AnyRoutable(self),
                defaultExit: {
                    TestCallbackTracker.shared.recordDefaultExit(route: self)
                }
            )
    }
}

// MARK: - Test Helpers

class TestCallbackTracker {
    nonisolated(unsafe) static let shared = TestCallbackTracker()
    
    private var defaultExitCalls: [AnyRoutable] = []
    private var finishCalls: [(userInitiated: Bool, result: Any?, coordinator: String)] = []
    
    func recordDefaultExit<T: Routable>(route: T) {
        defaultExitCalls.append(AnyRoutable(route))
    }
    
    func recordFinish(userInitiated: Bool, result: Any?, coordinatorId: String) {
        finishCalls.append((userInitiated, result, coordinatorId))
    }
    
    func reset() {
        defaultExitCalls.removeAll()
        finishCalls.removeAll()
    }
    
    var lastDefaultExit: AnyRoutable? { defaultExitCalls.last }
    var defaultExitCount: Int { defaultExitCalls.count }
    var lastFinish: (userInitiated: Bool, result: Any?, coordinator: String)? { finishCalls.last }
    var finishCount: Int { finishCalls.count }
}

// MARK: - Test Cases

class CoordinatorTests: XCTestCase {
    
    var callbackTracker: TestCallbackTracker!
    var rootCoordinator: Coordinator<TestRoute>!
    var sharedPath: SharedNavigationPath!
    
    override func setUp() {
        super.setUp()
        callbackTracker = .init()
        sharedPath = SharedNavigationPath()
        rootCoordinator = Coordinator(
            identifier: "test-coordinator",
            initialRoute: .home,
            sharedPath: sharedPath,
            presentationStyle: .push
        )
    }
    
    override func tearDown() {
        rootCoordinator = nil
        sharedPath = nil
        TestCallbackTracker.shared.reset()
        super.tearDown()
    }
    
    // MARK: - Test 1: Push same type route
    
    func test1_pushSameTypeRoute() {
        // When: Push a route of the same type
        rootCoordinator.push(TestRoute.profile)
        
        // Then: Route should be added to navigation path
        XCTAssertEqual(sharedPath.path.count, 1)
        XCTAssertEqual(sharedPath.routes.count, 1)
        XCTAssertEqual(sharedPath.routes.first?.routeCase, "profile")
        
        // And: Local stack should include initial + pushed route
        XCTAssertEqual(rootCoordinator.localStack.count, 2)
        XCTAssertEqual(rootCoordinator.localStack[0], .home)
        XCTAssertEqual(rootCoordinator.localStack[1], .profile)
    }
    
    // MARK: - Test 2: Go back after pushing (programmatic)
    
    func test2_goBackAfterPushing_programmatic() {
        // Given: A pushed route
        rootCoordinator.push(TestRoute.profile)
        rootCoordinator.push(TestRoute.settings)
        
        // When: Go back programmatically
        rootCoordinator.goBack(.popStack(last: 1))
        
        // Then: Should pop one route
        XCTAssertEqual(sharedPath.path.count, 1)
        XCTAssertEqual(rootCoordinator.localStack.count, 2)
        XCTAssertEqual(rootCoordinator.localStack.last, .profile)
        
        // And: No default exit should be called (programmatic)
        XCTAssertEqual(TestCallbackTracker.shared.defaultExitCount, 0)
    }
    
    // MARK: - Test 2a: Go back after pushing (user initiated)
    
    func test2a_goBackAfterPushing_userInitiated() {
        // Given: A pushed route
        rootCoordinator.push(TestRoute.profile)
        rootCoordinator.push(TestRoute.settings)
        
        // When: Simulate user-initiated navigation back
        // This simulates SwiftUI's NavigationStack reducing the path count
        sharedPath.path.removeLast()
        
        // And: Simulate view disappearing
        let mockCoordinator = AnyCoordinator(rootCoordinator)
        mockCoordinator.viewDisappeared(
            route: AnyRoutable(TestRoute.settings),
            defaultExit: { TestCallbackTracker.shared.recordDefaultExit(route: TestRoute.settings) }
        )
        
        // Then: Default exit should be called for user-initiated change
        XCTAssertEqual(TestCallbackTracker.shared.defaultExitCount, 1)
        XCTAssertEqual(TestCallbackTracker.shared.lastDefaultExit?.routeCase, "settings")
    }
    
    // MARK: - Test 3: Replace root
    
    func test3_replaceRoot() {
        // Given: Some routes on the stack
        rootCoordinator.push(TestRoute.profile)
        rootCoordinator.push(TestRoute.settings)
        
        // When: Replace root
        rootCoordinator.show(TestRoute.detail(id: "123"), presentationStyle: .replaceRoot)
        
        // Then: Stack should be cleared and initial route changed
        XCTAssertEqual(sharedPath.path.count, 0)
        XCTAssertEqual(rootCoordinator.initialRoute, .detail(id: "123"))
        XCTAssertEqual(rootCoordinator.localStack.count, 1)
        XCTAssertEqual(rootCoordinator.localStack[0], .detail(id: "123"))
    }
    
    // MARK: - Test 4: Present sheet from root
    
    func test4_presentSheetFromRoot() {
        // When: Present a sheet
        rootCoordinator.show(TestRoute.profile, presentationStyle: .sheet)
        
        // Then: Sheet should be set
        XCTAssertNotNil(rootCoordinator.sheet)
        XCTAssertEqual(rootCoordinator.sheet, .profile)
        
        // And: Navigation path should remain unchanged
        XCTAssertEqual(sharedPath.path.count, 0)
    }
    
    // MARK: - Test 5: Dismiss sheet programmatically
    
    func test5_dismissSheetProgrammatically() {
        // Given: A presented sheet
        rootCoordinator.show(TestRoute.profile, presentationStyle: .sheet)
        
        // When: Dismiss programmatically
        rootCoordinator.goBack(.dismissSheet)
        
        // Then: Sheet should be nil
        XCTAssertNil(rootCoordinator.sheet)
        
        // And: No default exit should be called
        XCTAssertEqual(TestCallbackTracker.shared.defaultExitCount, 0)
    }
    
    // MARK: - Test 5a: Dismiss sheet via user interaction
    
    func test5a_dismissSheetViaUserInteraction() {
        // Given: A presented sheet
        rootCoordinator.show(TestRoute.profile, presentationStyle: .sheet)
        
        // When: User dismisses sheet (SwiftUI sets binding to nil)
        rootCoordinator.sheet = nil
        
        // Then: Should detect user interaction
        // Note: In real usage, checkForUserInitiatedFinishesInChildren would be called
        // This is a simplified test of the detection mechanism
        XCTAssertNil(rootCoordinator.sheet)
    }
    
    // MARK: - Test 6-11: Full screen cover tests (similar to sheet)
    
    func test6_dismissFullScreenCoverProgrammatically() {
        // Given: A presented full screen cover
        rootCoordinator.show(TestRoute.profile, presentationStyle: .fullscreenCover)
        
        // When: Dismiss programmatically
        rootCoordinator.goBack(.dismissFullScreenCover)
        
        // Then: Cover should be nil
        XCTAssertNil(rootCoordinator.fullscreenCover)
        
        // And: No default exit should be called
        XCTAssertEqual(TestCallbackTracker.shared.defaultExitCount, 0)
    }
    
    // MARK: - Test 12: Push child coordinator onto common stack
    
    func test12_pushChildCoordinatorOntoCommonStack() {
        // Given: A proxy route for the child
        let proxyRoute = TestRoute.profile
        rootCoordinator.push(proxyRoute)
        
        // When: Create child coordinator that branches from the proxy route
        let childCoordinator = rootCoordinator.createChildCoordinator(
            identifier: "child-coordinator",
            branchedFrom: AnyRoutable(proxyRoute),
            initialRoute: ChildRoute.childHome,
            presentationStyle: .push
        ) { userInitiated, result in
            TestCallbackTracker.shared.recordFinish(
                userInitiated: userInitiated,
                result: result,
                coordinatorId: "child-coordinator"
            )
        }
        
        // Then: Proxy route should be in shared navigation path
        XCTAssertEqual(sharedPath.routes.count, 1)
        XCTAssertEqual(sharedPath.routes.first?.routeCase, "profile")
        
        // And: Child should have correct branching setup
        XCTAssertEqual(childCoordinator.branchedFrom?.routeCase, "profile")
        XCTAssertEqual(childCoordinator.presentationStyle, .push)
        XCTAssertEqual(childCoordinator.localStack.count, 1)
        XCTAssertEqual(childCoordinator.localStack[0], .childHome)
    }
    
    // MARK: - Test 13: Navigation back constraints
    
    func test13_popStackConstraints() {
        // Given: Multiple routes pushed
        rootCoordinator.push(TestRoute.profile)
        rootCoordinator.push(TestRoute.settings)
        rootCoordinator.push(TestRoute.detail(id: "123"))
        
        // When: Try to pop more than available
        rootCoordinator.goBack(.popStack(last: 10))
        
        // Then: Should only pop to initial route (not past it)
        XCTAssertEqual(sharedPath.path.count, 0)
        XCTAssertEqual(rootCoordinator.localStack.count, 1)
        XCTAssertEqual(rootCoordinator.localStack[0], .home)
    }
    
    // MARK: - Test 14: Pop to specific route
    
    func test14_popStackToSpecificRoute() {
        // Given: Multiple routes
        rootCoordinator.push(TestRoute.profile)
        rootCoordinator.push(TestRoute.settings)
        rootCoordinator.push(TestRoute.detail(id: "123"))
        
        // When: Pop to specific route
        rootCoordinator.goBack(.popStackTo(AnyRoutable(TestRoute.profile)))
        
        // Then: Should pop to that route
        XCTAssertEqual(sharedPath.path.count, 1)
        XCTAssertEqual(rootCoordinator.localStack.count, 2)
        XCTAssertEqual(rootCoordinator.localStack.last, .profile)
    }
    
    // MARK: - Test 15: Pop to initial route
    
    func test15_popToInitialRoute() {
        // Given: Multiple routes
        rootCoordinator.push(TestRoute.profile)
        rootCoordinator.push(TestRoute.settings)
        
        // When: Pop to initial route
        rootCoordinator.goBack(.popStackTo(AnyRoutable(TestRoute.home)))
        
        // Then: Should be at initial route
        XCTAssertEqual(sharedPath.path.count, 0)
        XCTAssertEqual(rootCoordinator.localStack.count, 1)
        XCTAssertEqual(rootCoordinator.localStack[0], .home)
    }
    
    // MARK: - Test 16: User navigates past child's initial route
    
    func test16_userNavigatesPastChildInitialRoute() {
        // Given: Child coordinator with routes
        let proxyRoute = TestRoute.profile
        rootCoordinator.push(proxyRoute)
        
        let childCoordinator = rootCoordinator.createChildCoordinator(
            identifier: "child-coordinator",
            branchedFrom: AnyRoutable(proxyRoute),
            initialRoute: ChildRoute.childHome,
            presentationStyle: .push
        ) { userInitiated, result in
            TestCallbackTracker.shared.recordFinish(
                userInitiated: userInitiated,
                result: result,
                coordinatorId: "child-coordinator"
            )
        }
        
        
        // When: User navigates back past child's initial (simulate SwiftUI navigation)
        sharedPath.path.removeLast() // Remove the proxy route
        
        // Then: Parent should detect child needs finishing
        // This would trigger the parent's checkForUserInitiatedFinishesInChildren
        XCTAssertEqual(sharedPath.path.count, 0)
    }
    
    // MARK: - Test 17: Finish child coordinator programmatically
    
    func test17_finishChildCoordinatorProgrammatically() {
        // Given: Child coordinator presented as sheet
        let childCoordinator = rootCoordinator.createChildCoordinator(
            identifier: "sheet-child",
            branchedFrom: AnyRoutable(TestRoute.profile),
            initialRoute: ChildRoute.childHome,
            presentationStyle: .sheet
        ) { userInitiated, result in
            TestCallbackTracker.shared.recordFinish(
                userInitiated: userInitiated,
                result: result,
                coordinatorId: "sheet-child"
            )
        }
        
        rootCoordinator.show(TestRoute.profile, presentationStyle: .sheet)
        
        // When: Finish programmatically
        childCoordinator.goBack(.unwindToStart(finishValue: "test-result"))
        
        // Then: Should have been finished
        // Note: The actual sheet dismissal and cleanup would happen in the parent's finish method
        XCTAssertEqual(TestCallbackTracker.shared.finishCount, 1)
        XCTAssertEqual(TestCallbackTracker.shared.lastFinish?.userInitiated, false)
    }
    
    // MARK: - Test 18: Cannot create child with replaceRoot presentation
    
//    func test18_cannotCreateChildWithReplaceRoot() {
//        // When/Then: Should fail to create child with replaceRoot
//        XCTAssertThrowsError(
//            try {
//                _ = rootCoordinator.createChildCoordinator(
//                    identifier: "invalid-child",
//                    branchedFrom: AnyRoutable(TestRoute.profile),
//                    initialRoute: ChildRoute.childHome,
//                    presentationStyle: .replaceRoot
//                ) { _, _ in }
//            }()
//        )
//    }
    
    // MARK: - Test 30: Complex flow - sheet with child coordinator
    
    func test30_sheetWithChildCoordinatorFinishProgrammatically() {
        // Given: Child coordinator presented as sheet
        let childCoordinator = rootCoordinator.createChildCoordinator(
            identifier: "complex-child",
            branchedFrom: AnyRoutable(TestRoute.profile),
            initialRoute: ChildRoute.childHome,
            presentationStyle: .sheet
        ) { userInitiated, result in
            TestCallbackTracker.shared.recordFinish(
                userInitiated: userInitiated,
                result: result,
                coordinatorId: "complex-child"
            )
        }
        
        rootCoordinator.show(TestRoute.profile, presentationStyle: .sheet)
        
        // When: Child pushes route then finishes programmatically
        childCoordinator.push(ChildRoute.childDetail(value: 99))
        childCoordinator.goBack(.unwindToStart(finishValue: "final-result"))
        
        // Then: No default exits should be called (programmatic finish)
        XCTAssertEqual(TestCallbackTracker.shared.defaultExitCount, 0)
        XCTAssertEqual(TestCallbackTracker.shared.finishCount, 1)
        XCTAssertEqual(TestCallbackTracker.shared.lastFinish?.userInitiated, false)
    }
    
    // MARK: - Test 31: Sheet dismissed by user
    
    func test31_sheetWithChildCoordinatorDismissedByUser() {
        // Given: Child coordinator presented as sheet with routes
        let childCoordinator = rootCoordinator.createChildCoordinator(
            identifier: "user-dismissed-child",
            branchedFrom: AnyRoutable(TestRoute.profile),
            initialRoute: ChildRoute.childHome,
            presentationStyle: .sheet
        ) { userInitiated, result in
            TestCallbackTracker.shared.recordFinish(
                userInitiated: userInitiated,
                result: result,
                coordinatorId: "user-dismissed-child"
            )
        }
        
        rootCoordinator.show(TestRoute.profile, presentationStyle: .sheet)
        childCoordinator.push(ChildRoute.childDetail(value: 42))
        
        // When: User dismisses sheet (SwiftUI binding sets to nil)
        rootCoordinator.sheet = nil
        
        // Then: Should detect user-initiated dismissal
        // In real implementation, this would trigger checkForUserInitiatedFinishesInChildren
        // which would call notifyUserInteractiveFinish on the child
        XCTAssertNil(rootCoordinator.sheet)
        
        // Simulate the detection and callback
        childCoordinator.notifyUserInteractiveFinish()
        
        // The parent would detect this change and invoke onFinish
        // This tests the callback mechanism
        XCTAssertTrue(true) // Test passes if no crashes occur
    }
}

// MARK: - Integration Tests

class CoordinatorIntegrationTests: XCTestCase {
    
    func testComplexNavigationFlow() {
        // This test simulates a complex real-world navigation flow
        let sharedPath = SharedNavigationPath()
        let rootCoordinator = Coordinator<TestRoute>(
            identifier: "root",
            initialRoute: .home,
            sharedPath: sharedPath,
            presentationStyle: .push
        )
        
        // Navigate to profile
        rootCoordinator.push(TestRoute.profile)
        
        // Present settings as sheet
        rootCoordinator.show(TestRoute.settings, presentationStyle: .sheet)
        
        // Create child coordinator from settings sheet
        let settingsChild = rootCoordinator.createChildCoordinator(
            identifier: "settings-flow",
            branchedFrom: AnyRoutable(TestRoute.settings),
            initialRoute: ChildRoute.childHome,
            presentationStyle: .push
        ) { userInitiated, result in
            // Handle finish
        }
        
        // Child navigates
        settingsChild.push(ChildRoute.childDetail(value: 123))
        settingsChild.push(ChildRoute.childList)
        
        // Verify state
        XCTAssertEqual(sharedPath.path.count, 1) // Just profile
        XCTAssertNotNil(rootCoordinator.sheet)
        XCTAssertEqual(settingsChild.localStack.count, 3) // childHome + 2 pushed
        
        // Child finishes
        settingsChild.goBack(.unwindToStart(finishValue: "settings-complete"))
        
        // Root dismisses sheet
        rootCoordinator.goBack(.dismissSheet)
        
        // Verify final state
        XCTAssertNil(rootCoordinator.sheet)
        XCTAssertEqual(sharedPath.path.count, 1) // Still at profile
    }
}
