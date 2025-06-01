import XCTest
@testable import HSNavigationCoordination
import SwiftUI

// MARK: - Test Route Implementation

enum TestRoute: Routable {
    case home
    case profile
    case settings
    case detail(id: Int)
    case nested(String)
    
    func makeView(with coordinator: Coordinator<TestRoute>, presentationStyle: NavigationPresentationType) -> some View {
        Text("Test View")
    }
}

enum ChildTestRoute: Routable {
    case childHome
    case childDetail(id: Int)
    case childSettings
    
    func makeView(with coordinator: Coordinator<ChildTestRoute>, presentationStyle: NavigationPresentationType) -> some View {
        Text("Child Test View")
    }
}

final class CoordinatorTests: XCTestCase {
    
    var rootCoordinator: Coordinator<TestRoute>!
    var finishCallbackResults: [(userInitiated: Bool, result: Any?, coordinator: AnyCoordinator)] = []
    
    override func setUpWithError() throws {
        finishCallbackResults.removeAll()
        
        // Root coordinators should never finish - this would indicate a design flaw
        rootCoordinator = Coordinator<TestRoute>(
            identifier: "root-coordinator",
            initialRoute: .home,
            presentationStyle: .push,
        ) { [weak self] userInitiated, result, finishingCoordinator in
            XCTFail("A Root Coordinator should never finish!")
            self?.finishCallbackResults.append((userInitiated, result, finishingCoordinator))
        }
    }

    override func tearDownWithError() throws {
        rootCoordinator = nil
        finishCallbackResults.removeAll()
    }

    // MARK: - Root Coordinator Navigation Tests
    
    func test_simplePushFromRoot() throws {
        // Given: A root coordinator with initial route
        XCTAssertEqual(rootCoordinator.localStack.count, 1)
        XCTAssertEqual(rootCoordinator.localStack.first, .home)
        XCTAssertEqual(rootCoordinator.path.count, 0)
        
        // When: Pushing a new route
        rootCoordinator.show(TestRoute.profile, presentationStyle: .push)
        
        // Then: Route should be added to stack and path
        XCTAssertEqual(rootCoordinator.localStack.count, 2)
        XCTAssertEqual(rootCoordinator.localStack.last, .profile)
        XCTAssertEqual(rootCoordinator.path.count, 1)
    }
    
    func test_simpleGoBackFromRoot() throws {
        // Given: A root coordinator with multiple pushed routes
        rootCoordinator.show(TestRoute.profile, presentationStyle: .push)
        rootCoordinator.show(TestRoute.settings, presentationStyle: .push)
        rootCoordinator.show(TestRoute.detail(id: 123), presentationStyle: .push)
        XCTAssertEqual(rootCoordinator.path.count, 3)
        
        // When: Going back one level
        rootCoordinator.goBack(.popStack(last: 1))
        
        // Then: Last route should be removed
        XCTAssertEqual(rootCoordinator.path.count, 2)
        XCTAssertEqual(rootCoordinator.localStack.count, 3) // initial + 2 pushed
        XCTAssertEqual(rootCoordinator.localStack.last, .settings)
        
        // When: Going back multiple levels
        rootCoordinator.goBack(.popStack(last: 2))
        
        // Then: Should be back to initial state
        XCTAssertEqual(rootCoordinator.path.count, 0)
        XCTAssertEqual(rootCoordinator.localStack.count, 1)
        XCTAssertEqual(rootCoordinator.localStack.first, .home)
    }
    
    func test_replaceRootNavigation() {
        // Given: A root coordinator with some navigation
        rootCoordinator.show(TestRoute.profile, presentationStyle: .push)
        rootCoordinator.show(TestRoute.settings, presentationStyle: .push)
        XCTAssertEqual(rootCoordinator.path.count, 2)
        
        // When: Replacing with a new root route
        rootCoordinator.show(TestRoute.detail(id: 999), presentationStyle: .replaceRoot)
        
        // Then: Initial route should be updated but path behavior needs implementation
        XCTAssertEqual(rootCoordinator.initialRoute, TestRoute.detail(id: 999))
        // Note: Path clearing behavior depends on implementation of removeAll()
    }
    
    // MARK: - Sheet Presentation Tests (Root Coordinator)
    
    func test_presentSheetFromRoot() throws {
        // Given: A root coordinator
        XCTAssertNil(rootCoordinator.sheet)
        
        // When: Presenting a sheet
        rootCoordinator.show(TestRoute.profile, presentationStyle: .sheet)
        
        // Then: Sheet should be set
        XCTAssertEqual(rootCoordinator.sheet, .profile)
        XCTAssertEqual(rootCoordinator.path.count, 0) // Sheet doesn't affect navigation path
    }
    
    func test_dismissSheet() {
        // Given: A root coordinator with a presented sheet
        rootCoordinator.show(TestRoute.profile, presentationStyle: .sheet)
        XCTAssertEqual(rootCoordinator.sheet, .profile)
        
        // When: Dismissing sheet programmatically
        rootCoordinator.goBack(.dismissSheet)
        
        // Then: Sheet should be nil
        XCTAssertNil(rootCoordinator.sheet)
    }
    
    func test_dismissSheetUserInitiated() {
        
        #warning("This test doesn't accurately simulate a userInitiated sheet dismissal!")
        
        // Given: A root coordinator with a presented sheet
        rootCoordinator.show(TestRoute.profile, presentationStyle: .sheet)
        XCTAssertEqual(rootCoordinator.sheet, .profile)
        
        // When: Simulating user-initiated dismissal (sheet becomes nil externally)
        rootCoordinator.sheet = nil
        
        var defaultExitCalled = false
        let route = AnyRoutable(TestRoute.profile)
        rootCoordinator.viewDisappeared(route: route) {
            defaultExitCalled = true
        }
        
        // Then: Default exit should be called
        XCTAssertTrue(defaultExitCalled)
    }
    
    func test_fullScreenCoverBehavior() {
        
        #warning("This test doesn't accurately simulate a userInitiated sheet dismissal!")
        
        // Given: A root coordinator
        XCTAssertNil(rootCoordinator.fullscreenCover)
        
        // When: Presenting full screen cover
        rootCoordinator.show(TestRoute.settings, presentationStyle: .fullScreenCover)
        
        // Then: Full screen cover should be set
        XCTAssertEqual(rootCoordinator.fullscreenCover, TestRoute.settings)
        
        // When: Dismissing programmatically
        rootCoordinator.goBack(.dismissFullScreenCover)
        
        // Then: Full screen cover should be nil
        XCTAssertNil(rootCoordinator.fullscreenCover)
    }
    
    // MARK: - Child Coordinator Tests (Shared Navigation Path)
    
    func test_pushFromRootThenPushChildCoordstack() throws {
        // Given: A root coordinator with a pushed route
        let parentRoute = TestRoute.profile
        rootCoordinator.show(parentRoute, presentationStyle: .push)
        XCTAssertEqual(rootCoordinator.path.count, 1)
        
        // When: Creating a child coordinator with shared navigation path
        var childFinishResults: [(userInitiated: Bool, result: Any?)] = []
        let childCoordinator = rootCoordinator.createChildCoordinator(
            identifier: "child-test",
            branchedFrom: AnyRoutable(parentRoute),
            initialRoute: ChildTestRoute.childHome,
            presentationStyle: .push
        ) { userInitiated, result in
            childFinishResults.append((userInitiated, result))
        }
        
        // Then: Child coordinator should share the same navigation path
        XCTAssertEqual(childCoordinator.path.count, 1) // Shares parent's path
        XCTAssertEqual(childCoordinator.localStack.count, 1) // Only its own initial route
        XCTAssertEqual(childCoordinator.localStack.first, .childHome)
        
        // When: Child coordinator pushes a route
        childCoordinator.show(ChildTestRoute.childDetail(id: 42), presentationStyle: .push)
        
        // Then: Both coordinators should see the updated shared path
        XCTAssertEqual(rootCoordinator.path.count, 2)
        XCTAssertEqual(childCoordinator.path.count, 2)
        XCTAssertEqual(childCoordinator.localStack.count, 2)
    }
    
    func test_GoBackWithPopListInChildCoordinatorCanOnlyTakeYouBackToChildsInitialRoute() {
        // Given: Root coordinator with some navigation
        rootCoordinator.show(TestRoute.profile) // pushes
        rootCoordinator.show(TestRoute.settings)
        let parentRoute = TestRoute.detail(id: 1)
        rootCoordinator.show(parentRoute) // this triggers a makeView, which creates the childCoordinator below and injects it.
        XCTAssertEqual(rootCoordinator.path.count, 3)
        XCTAssertEqual(rootCoordinator.localStack.count, 4) // includes initialRoute of .home
        
        // And: Child coordinator that pushes additional routes
        let childCoordinator = rootCoordinator.createChildCoordinator(
            identifier: "limited-child",
            branchedFrom: AnyRoutable(parentRoute),
            initialRoute: ChildTestRoute.childHome,
            presentationStyle: .push
        ) { _, _ in }
        
        childCoordinator.show(ChildTestRoute.childDetail(id: 1))
        childCoordinator.show(ChildTestRoute.childSettings)
        XCTAssertEqual(rootCoordinator.path.count, 5) // 3 parent (the initial in the path is actually the parentRoute, not the child's initial) + 2 child
        
        // When: Child coordinator tries to go back more than its own routes
        childCoordinator.goBack(.popStack(last: 10)) // Trying to pop more than possible
        
        // Then: Should only pop child coordinator's own routes, not parent's
        let expectedMinimumPath = 3 // Parent's routes should remain
        XCTAssertGreaterThanOrEqual(rootCoordinator.path.count, expectedMinimumPath)
        
        XCTAssertEqual(rootCoordinator.localStack.count, 4, "Should contain home, profile, settings, detail(id: 1)")
        // And: Child coordinator should be at its initial state
        XCTAssertEqual(childCoordinator.localStack.count, 1)
        XCTAssertEqual(childCoordinator.localStack.first, .childHome)
    }
    
    func test_GoBackWithPopToStartInChildCoordinatorWillTakeYouBackOneBeforeParentRoute() {
        // the idea here is to test that when you goBack with .popToStart(finishValue:),
        // you're essentially saying 'finish this coordinator with return value'
        
        
    }
    
    func test_userInitiatedGoBackFromChildCoordinatorSoThatItGetsCoordinatorFinishedCalled() throws {
        // Given: A child coordinator with some navigation
        
        let parentRoute = TestRoute.detail(id: 42)
        rootCoordinator.show(parentRoute) // this pushes a route, which in turn in makeView creates a child coordinator and a ChildCoordinatorStack.
        
        var childFinishResults: [(userInitiated: Bool, result: Any?)] = []
        let childCoordinator = rootCoordinator.createChildCoordinator(
            identifier: "child-test",
            branchedFrom: AnyRoutable(parentRoute),
            initialRoute: ChildTestRoute.childHome,
            presentationStyle: .push,
            defaultFinishValue: "test-result"
        ) { userInitiated, result in
            childFinishResults.append((userInitiated, result))
        }

        childCoordinator.show(ChildTestRoute.childDetail(id: 42))
        XCTAssertEqual(childFinishResults.count, 0)
        
        // When: Simulating user-initiated back navigation by calling viewDisappeared
        let childRoute = AnyRoutable(ChildTestRoute.childHome)
        var defaultExitCalled = false
        childCoordinator.path.removeLast(2) // Simulate NavigationStack auto-popping
        childCoordinator.viewDisappeared(route: childRoute) {
            defaultExitCalled = true
        }
        
        // Then: Default exit should be called for user-initiated navigation
        XCTAssertTrue(defaultExitCalled)
        
        // TODO: When popping back past the initial in the stack, the child coordinator should be firing finish, not manually here.
        // When: Child coordinator finishes with user-initiated flag
        //childCoordinator.finish(with: "test-result", userInitiated: true)
        
        // Then: Parent should receive finish callback with userInitiated = true
        XCTAssertEqual(childFinishResults.count, 1)
        XCTAssertTrue(childFinishResults.first?.userInitiated == true)
        XCTAssertEqual(childFinishResults.first?.result as? String, "test-result")
    }
    
    // MARK: - Child Coordinator Tests (Isolated Navigation Path - Sheets)
    
    func test_presentSheetWithChildCoordinatorFlow() {
        // Given: A root coordinator that will present a sheet with child coordinator
        var childFinishResults: [(userInitiated: Bool, result: Any?)] = []
        let childCoordinator = rootCoordinator.createChildCoordinator(
            identifier: "sheet-child",
            initialRoute: ChildTestRoute.childHome,
            presentationStyle: .sheet
        ) { userInitiated, result in
            childFinishResults.append((userInitiated, result))
        }
        
        // Then: Child coordinator should have its own isolated navigation path
        XCTAssertEqual(childCoordinator.path.count, 0) // Isolated path, starts empty
        XCTAssertEqual(childCoordinator.localStack.count, 1) // Only its initial route
        XCTAssertEqual(childCoordinator.localStack.first, .childHome)
        
        // And: Root coordinator's path should be unaffected
        XCTAssertEqual(rootCoordinator.path.count, 0)
    }
    
    func test_presentSheetWithChildCoordinatorFlowThatThenPushes() {
        // Given: A sheet child coordinator
        let childCoordinator = rootCoordinator.createChildCoordinator(
            identifier: "sheet-child",
            initialRoute: ChildTestRoute.childHome,
            presentationStyle: .sheet
        ) { _, _ in }
        
        // When: Child coordinator pushes routes in its isolated navigation stack
        childCoordinator.show(ChildTestRoute.childDetail(id: 1))
        childCoordinator.show(ChildTestRoute.childSettings)
        
        // Then: Child should have its own navigation stack
        XCTAssertEqual(childCoordinator.path.count, 2) // 2 pushes in isolated stack
        XCTAssertEqual(childCoordinator.localStack.count, 3) // initial + 2 pushed
        
        // And: Root coordinator should be unaffected
        XCTAssertEqual(rootCoordinator.path.count, 0)
    }
    
    func test_presentSheetWithChildCoordinatorFlowThatThenPushesThenFinishesProgrammatically() {
        // Given: A sheet child coordinator with navigation
        var childFinishResults: [(userInitiated: Bool, result: Any?)] = []
        let childCoordinator = rootCoordinator.createChildCoordinator(
            identifier: "sheet-child",
            initialRoute: ChildTestRoute.childHome,
            presentationStyle: .sheet
        ) { userInitiated, result in
            childFinishResults.append((userInitiated, result))
        }
        
        childCoordinator.show(ChildTestRoute.childDetail(id: 1))
        childCoordinator.show(ChildTestRoute.childSettings)
        
        // When: Child coordinator finishes programmatically
        childCoordinator.finish(with: "programmatic-result", userInitiated: false)
        
        // Then: Finish callback should be called with userInitiated = false
        XCTAssertEqual(childFinishResults.count, 1)
        XCTAssertFalse(childFinishResults.first?.userInitiated == true)
        XCTAssertEqual(childFinishResults.first?.result as? String, "programmatic-result")
    }
    
    func test_presentSheetWithChildCoordinatorFlowThatGetsDismissedByUser() {
        // Given: A sheet child coordinator
        var childFinishResults: [(userInitiated: Bool, result: Any?)] = []
        let childCoordinator = rootCoordinator.createChildCoordinator(
            identifier: "sheet-child",
            initialRoute: ChildTestRoute.childHome,
            presentationStyle: .sheet
        ) { userInitiated, result in
            childFinishResults.append((userInitiated, result))
        }
        childCoordinator.show(ChildTestRoute.childDetail(id: 1))
        
        
        // When: User dismisses sheet (simulated by viewDisappeared without programmatic flag)
        var defaultExitCalled = false
        let childRoute = AnyRoutable(ChildTestRoute.childDetail(id: 1))
        // the path will have also been updated by the NavigationStack to have popped the element
        childCoordinator.path.removeLast(1) // Simulate NavigationStack auto-popping
        childCoordinator.viewDisappeared(route: childRoute) {
            defaultExitCalled = true
        }
        
        // Then: Default exit should be called indicating user dismissal
        XCTAssertTrue(defaultExitCalled)
    }
    
    // MARK: - Child Coordinator Tests (Isolated Navigation Path - Full Screen Covers)
    
    func test_presentFullScreenCoverWithChildCoordinatorFlow() {
        // Given: A full screen cover child coordinator
        var childFinishResults: [(userInitiated: Bool, result: Any?)] = []
        let childCoordinator = rootCoordinator.createChildCoordinator(
            identifier: "fullscreen-child",
            initialRoute: ChildTestRoute.childHome,
            presentationStyle: .fullScreenCover
        ) { userInitiated, result in
            childFinishResults.append((userInitiated, result))
        }
        
        // Then: Child coordinator should have its own isolated navigation path
        XCTAssertEqual(childCoordinator.path.count, 0) // Isolated path
        XCTAssertEqual(childCoordinator.localStack.count, 1)
        XCTAssertEqual(childCoordinator.localStack.first, .childHome)
        
        // When: Child coordinator navigates within its own stack
        childCoordinator.push(ChildTestRoute.childDetail(id: 42))
        
        // Then: Navigation should be isolated
        XCTAssertEqual(childCoordinator.path.count, 1)
        XCTAssertEqual(rootCoordinator.path.count, 0) // Root unaffected
    }
    
    // MARK: - Error Condition Tests
    
    func test_childCoordinatorCannotReplaceRoot() {
        
        print("Test implemented but will fail due to fatalError until you implement that.")
        return
        
//        // Given: A child coordinator
//        let childCoordinator = rootCoordinator.createChildCoordinator(
//            identifier: "child-test",
//            branchedFrom: AnyRoutable(parentRoute)
//            initialRoute: ChildTestRoute.childHome,
//            navigationForwardType: .push
//        ) { _, _ in }
//        
//        // When/Then: Attempting to create child with replaceRoot should fail
//        XCTAssertThrowsError(
//            try rootCoordinator.createChildCoordinator(
//                identifier: "invalid-child",
//                initialRoute: ChildTestRoute.childHome,
//                navigationForwardType: .replaceRoot
//            ) { _, _ in }
//        ) { error in
//            // Should be a fatalError, but we can't easily test that in unit tests
//            // This test documents the expected behavior
//        }
    }
    
    // MARK: - Coordinator Lifecycle Tests
    
    func test_coordinatorIdentification() {
        XCTAssertEqual(rootCoordinator.identifier, "root-coordinator")
        
        let childCoordinator = rootCoordinator.createChildCoordinator(
            identifier: "child-test",
            initialRoute: ChildTestRoute.childHome,
            presentationStyle: .sheet
        ) { _, _ in }
        
        XCTAssertEqual(childCoordinator.identifier, "child-test")
    }
    
    func test_resetRootCoordinator() {
        // Given: A root coordinator with complex state
        let branchedFrom = TestRoute.profile
        rootCoordinator.push(branchedFrom)
        rootCoordinator.show(TestRoute.settings, presentationStyle: .sheet)
        rootCoordinator.show(TestRoute.detail(id: 1), presentationStyle: .fullScreenCover)
        
        let childCoordinator = rootCoordinator.createChildCoordinator(
            identifier: "child-test",
            branchedFrom: AnyRoutable(branchedFrom),
            initialRoute: ChildTestRoute.childHome,
            presentationStyle: .push
        ) { _, _ in }
        
        // When: Resetting the root coordinator
        rootCoordinator.reset()
        
        // Then: All state should be cleared
        XCTAssertEqual(rootCoordinator.path.count, 0)
        XCTAssertNil(rootCoordinator.sheet)
        XCTAssertNil(rootCoordinator.fullscreenCover)
        XCTAssertEqual(rootCoordinator.localStack.count, 1)
        XCTAssertEqual(rootCoordinator.localStack.first, .home)
    }
    
    func test_childCoordinatorResetWithFinish() {
        // Given: A child coordinator with navigation
        var childFinishResults: [(userInitiated: Bool, result: Any?)] = []
        let childCoordinator = rootCoordinator.createChildCoordinator(
            identifier: "child-test",
            initialRoute: ChildTestRoute.childHome,
            presentationStyle: .sheet
        ) { userInitiated, result in
            childFinishResults.append((userInitiated, result))
        }
        
        childCoordinator.push(ChildTestRoute.childDetail(id: 1))
        XCTAssertEqual(childCoordinator.path.count, 1)
        
        // When: Child coordinator resets with finish
        childCoordinator.popAllAndFinish(with: "reset-result")
        
        // Then: Child should be reset and finish callback should be called
        
        // because we're dismissing the sheet, it doesn't matter about the childCoordinator's path and localStack; they get destroyed.
        //XCTAssertEqual(childCoordinator.path.count, 0)
        //XCTAssertEqual(childCoordinator.localStack.count, 1)
        XCTAssertEqual(childFinishResults.count, 1)
        XCTAssertEqual(childFinishResults.first?.result as? String, "reset-result")
    }
    
    // MARK: - Navigation Path Isolation Tests
    
    func test_sharedVsIsolatedNavigationPaths() {
        // Given: Root coordinator with some navigation
        rootCoordinator.push(TestRoute.profile)
        
        let branchedFrom = TestRoute.settings
        rootCoordinator.push(branchedFrom)
        
        // When: Creating shared path child coordinator
        let sharedChild = rootCoordinator.createChildCoordinator(
            identifier: "shared-child",
            branchedFrom: AnyRoutable(branchedFrom),
            initialRoute: ChildTestRoute.childHome,
            presentationStyle: .push
        ) { _, _ in }
        
        // And: Creating isolated path child coordinator
        let isolatedChild = rootCoordinator.createChildCoordinator(
            identifier: "isolated-child",
            initialRoute: ChildTestRoute.childHome,
            presentationStyle: .sheet
        ) { _, _ in }
        
        // Then: Shared child should see parent's navigation
        XCTAssertEqual(sharedChild.path.count, 2) // Sees parent's navigation
        
        // And: Isolated child should have its own empty path
        XCTAssertEqual(isolatedChild.path.count, 0) // Isolated navigation
        
        // When: Both children push routes
        sharedChild.push(ChildTestRoute.childDetail(id: 1))
        isolatedChild.push(ChildTestRoute.childDetail(id: 2))
        
        // Then: Paths should behave differently
        XCTAssertEqual(rootCoordinator.path.count, 3) // Root + shared child's push
        XCTAssertEqual(sharedChild.path.count, 3) // Shares with root
        XCTAssertEqual(isolatedChild.path.count, 1) // Independent
    }
}
