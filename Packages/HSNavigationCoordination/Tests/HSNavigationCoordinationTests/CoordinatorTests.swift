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
    
    func makeView(with coordinator: Coordinator<TestRoute>) -> some View {
        // Simple stub implementation for testing
        Text("Test View")
    }
}

enum ChildTestRoute: Routable {
    case childHome
    case childDetail(id: Int)
    case childSettings
    
    func makeView(with coordinator: Coordinator<ChildTestRoute>) -> some View {
        Text("Child Test View")
    }
}

final class CoordinatorTests: XCTestCase {
    
    var coordinator: Coordinator<TestRoute>!
    var finishCallbackResults: [(userInitiated: Bool, result: Any?, coordinator: AnyCoordinator)] = []
    
    override func setUpWithError() throws {
        finishCallbackResults.removeAll()
        
        coordinator = Coordinator<TestRoute>(
            identifier: "test-coordinator",
            initialRoute: .home
        ) { [weak self] userInitiated, result, finishingCoordinator in
            XCTFail("A Root Coordinator should never finish!")
            self?.finishCallbackResults.append((userInitiated, result, finishingCoordinator))
        }
    }

    override func tearDownWithError() throws {
        coordinator = nil
        finishCallbackResults.removeAll()
    }

    func test_simplePushFromRoot() throws {
        // Given: A coordinator with initial route
        XCTAssertEqual(coordinator.localStack.count, 1)
        XCTAssertEqual(coordinator.localStack.first, .home)
        XCTAssertEqual(coordinator.path.count, 0)
        
        // When: Pushing a new route
        coordinator.push(TestRoute.profile)
        
        // Then: Route should be added to stack and path
        XCTAssertEqual(coordinator.localStack.count, 2)
        XCTAssertEqual(coordinator.localStack.last, .profile)
        XCTAssertEqual(coordinator.path.count, 1)
    }

    func test_pushFromRootThenPushChildCoordstack() throws {
        // Given: A coordinator with a pushed route
        coordinator.push(TestRoute.profile)
        XCTAssertEqual(coordinator.path.count, 1)
        
        // When: Creating and using a child coordinator
        var childFinishResults: [(userInitiated: Bool, result: Any?)] = []
        let childCoordinator = coordinator.createChildCoordinator(
            identifier: "child-test",
            initialRoute: ChildTestRoute.childHome
        ) { userInitiated, result in
            childFinishResults.append((userInitiated, result))
        }
        
        // Then: Child coordinator should share the same navigation path
        XCTAssertEqual(childCoordinator.path.count, 1)
        XCTAssertEqual(childCoordinator.localStack.count, 1)
        XCTAssertEqual(childCoordinator.localStack.first, .childHome)
        
        // When: Child coordinator pushes a route
        childCoordinator.push(ChildTestRoute.childDetail(id: 42))
        
        // Then: Both coordinators should see the updated path
        XCTAssertEqual(coordinator.path.count, 2)
        XCTAssertEqual(childCoordinator.path.count, 2)
        XCTAssertEqual(childCoordinator.localStack.count, 2)
    }
    
    func test_simpleGoBackFromRoot() throws {
        // Given: A coordinator with multiple pushed routes
        coordinator.push(TestRoute.profile)
        coordinator.push(TestRoute.settings)
        coordinator.push(TestRoute.detail(id: 123))
        XCTAssertEqual(coordinator.path.count, 3)
        
        // When: Going back one level
        coordinator.goBack(.pop(last: 1))
        
        // Then: Last route should be removed
        XCTAssertEqual(coordinator.path.count, 2)
        XCTAssertEqual(coordinator.localStack.count, 3) // initial + 2 pushed
        XCTAssertEqual(coordinator.localStack.last, .settings)
        
        // When: Going back multiple levels
        coordinator.goBack(.pop(last: 2))
        
        // Then: Should be back to initial state
        XCTAssertEqual(coordinator.path.count, 0)
        XCTAssertEqual(coordinator.localStack.count, 1)
        XCTAssertEqual(coordinator.localStack.first, .home)
    }
    
    func test_userInitiatedGoBackFromChildCoordinatorSoThatItGetsCoordinatorFinishedCalled() throws {
        // Given: A child coordinator with some navigation
        var childFinishResults: [(userInitiated: Bool, result: Any?)] = []
        let childCoordinator = coordinator.createChildCoordinator(
            identifier: "child-test",
            initialRoute: ChildTestRoute.childHome
        ) { userInitiated, result in
            childFinishResults.append((userInitiated, result))
        }
        
        childCoordinator.push(ChildTestRoute.childDetail(id: 42))
        XCTAssertEqual(childFinishResults.count, 0)
        
        // When: Simulating user-initiated back navigation by calling viewDisappeared
        let childRoute = AnyRoutable(ChildTestRoute.childHome)
        var defaultExitCalled = false
        childCoordinator.viewDisappeared(route: childRoute) {
            defaultExitCalled = true
        }
        
        // Then: Default exit should be called for user-initiated navigation
        XCTAssertTrue(defaultExitCalled)
        
        // When: Child coordinator finishes with user-initiated flag
        childCoordinator.finish(with: "test-result", userInitiated: true)
        
        // Then: Parent should receive finish callback with userInitiated = true
        XCTAssertEqual(childFinishResults.count, 1)
        XCTAssertTrue(childFinishResults.first?.userInitiated == true)
        XCTAssertEqual(childFinishResults.first?.result as? String, "test-result")
    }
    
    func test_presentSheetFromRoot() throws {
        // Given: A coordinator at root
        XCTAssertNil(coordinator.sheet)
        
        // When: Presenting a sheet
        coordinator.push(TestRoute.profile, type: .sheet)
        
        // Then: Sheet should be set
        XCTAssertEqual(coordinator.sheet, .profile)
        XCTAssertEqual(coordinator.path.count, 0) // Sheet doesn't affect navigation path
    }
    
    func test_dismissSheet() {
        // Given: A coordinator with a presented sheet
        coordinator.push(TestRoute.profile, type: .sheet)
        XCTAssertEqual(coordinator.sheet, .profile)
        
        // When: Dismissing sheet programmatically
        coordinator.goBack(.dismissSheet)
        
        // Then: Sheet should be nil
        XCTAssertNil(coordinator.sheet)
    }
    
    func test_dismissSheetUserInitiated() {
        // Given: A coordinator with a presented sheet
        coordinator.push(TestRoute.profile, type: .sheet)
        XCTAssertEqual(coordinator.sheet, .profile)
        
        // When: Simulating user-initiated dismissal (sheet becomes nil externally)
        coordinator.sheet = nil
        
        var defaultExitCalled = false
        let route = AnyRoutable(TestRoute.profile)
        coordinator.viewDisappeared(route: route) {
            defaultExitCalled = true
        }
        
        // Then: Default exit should be called
        XCTAssertTrue(defaultExitCalled)
    }
    
    func test_presentSheetWithChildCoordinatorFlow() {
        // Given: A sheet presented with a child coordinator
        coordinator.push(TestRoute.profile, type: .sheet)
        
        var childFinishResults: [(userInitiated: Bool, result: Any?)] = []
        let childCoordinator = coordinator.createChildCoordinator(
            identifier: "sheet-child",
            initialRoute: ChildTestRoute.childHome
        ) { userInitiated, result in
            childFinishResults.append((userInitiated, result))
        }
        
        // Then: Child coordinator should be properly initialized
        XCTAssertEqual(childCoordinator.localStack.count, 1)
        XCTAssertEqual(childCoordinator.localStack.first, .childHome)
        XCTAssertEqual(coordinator.sheet, .profile)
    }
    
    func test_presentSheetWithChildCoordinatorFlowThatThenPushes() {
        // Given: A sheet with child coordinator
        coordinator.push(TestRoute.profile, type: .sheet)
        
        let childCoordinator = coordinator.createChildCoordinator(
            identifier: "sheet-child",
            initialRoute: ChildTestRoute.childHome
        ) { _, _ in }
        
        // When: Child coordinator pushes routes
        childCoordinator.push(ChildTestRoute.childDetail(id: 1))
        childCoordinator.push(ChildTestRoute.childSettings)
        
        // Then: Navigation should work within the sheet context
        XCTAssertEqual(childCoordinator.path.count, 2)
        XCTAssertEqual(childCoordinator.localStack.count, 3)
        XCTAssertEqual(coordinator.sheet, TestRoute.profile) // Parent sheet unchanged
    }
    
    func test_presentSheetWithChildCoordinatorFlowThatThenPushesThenFinishesProgrammatically() {
        // Given: A sheet with child coordinator that has pushed routes
        coordinator.push(TestRoute.profile, type: .sheet)
        
        var childFinishResults: [(userInitiated: Bool, result: Any?)] = []
        let childCoordinator = coordinator.createChildCoordinator(
            identifier: "sheet-child",
            initialRoute: ChildTestRoute.childHome
        ) { userInitiated, result in
            childFinishResults.append((userInitiated, result))
        }
        
        childCoordinator.push(ChildTestRoute.childDetail(id: 1))
        childCoordinator.push(ChildTestRoute.childSettings)
        
        // When: Child coordinator finishes programmatically
        childCoordinator.finish(with: "programmatic-result", userInitiated: false)
        
        // Then: Finish callback should be called with userInitiated = false
        XCTAssertEqual(childFinishResults.count, 1)
        XCTAssertFalse(childFinishResults.first?.userInitiated == true)
        XCTAssertEqual(childFinishResults.first?.result as? String, "programmatic-result")
    }
    
    func test_presentSheetWithChildCoordinatorFlowThatGetsDismissedByUser() {
        // Given: A sheet with child coordinator
        coordinator.push(TestRoute.profile, type: .sheet)
        
        var childFinishResults: [(userInitiated: Bool, result: Any?)] = []
        let childCoordinator = coordinator.createChildCoordinator(
            identifier: "sheet-child",
            initialRoute: ChildTestRoute.childHome
        ) { userInitiated, result in
            childFinishResults.append((userInitiated, result))
        }
        
        childCoordinator.push(ChildTestRoute.childDetail(id: 1))
        
        // When: User dismisses sheet (sheet becomes nil externally)
        coordinator.sheet = nil
        
        var defaultExitCalled = false
        let childRoute = AnyRoutable(ChildTestRoute.childHome)
        childCoordinator.viewDisappeared(route: childRoute) {
            defaultExitCalled = true
        }
        
        // Then: Default exit should be called indicating user dismissal
        XCTAssertTrue(defaultExitCalled)
    }
    
    func test_thatGoBackFromChildCoordinatorCanOnlyTakeYouBackToWhereTheCoordinatorBegan() {
        // Given: Parent coordinator with some navigation
        coordinator.push(TestRoute.profile)
        coordinator.push(TestRoute.settings)
        XCTAssertEqual(coordinator.path.count, 2)
        
        // And: Child coordinator that pushes additional routes
        let childCoordinator = coordinator.createChildCoordinator(
            identifier: "limited-child",
            initialRoute: ChildTestRoute.childHome
        ) { _, _ in }
        
        childCoordinator.push(ChildTestRoute.childDetail(id: 1))
        childCoordinator.push(ChildTestRoute.childSettings)
        XCTAssertEqual(coordinator.path.count, 4) // 2 parent + 2 child
        
        // When: Child coordinator tries to go back more than its own routes
        let initialChildStackSize = childCoordinator.localStack.count
        childCoordinator.goBack(.pop(last: 10)) // Trying to pop more than possible
        
        // Then: Should only pop child coordinator's own routes, not parent's
        let expectedMinimumPath = 2 // Parent's routes should remain
        XCTAssertGreaterThanOrEqual(coordinator.path.count, expectedMinimumPath)
        
        // And: Child coordinator should be at its initial state
        XCTAssertEqual(childCoordinator.localStack.count, 1)
        XCTAssertEqual(childCoordinator.localStack.first, .childHome)
    }
    
    // MARK: - Additional Helper Tests
    
    func test_coordinatorIdentification() {
        XCTAssertEqual(coordinator.identifier, "test-coordinator")
        
        let childCoordinator = coordinator.createChildCoordinator(
            identifier: "child-test",
            initialRoute: ChildTestRoute.childHome
        ) { _, _ in }
        
        XCTAssertEqual(childCoordinator.identifier, "child-test")
    }
    
    func test_resetCoordinator() {
        // Given: A coordinator with complex state
        coordinator.push(TestRoute.profile)
        coordinator.push(TestRoute.settings, type: .sheet)
        coordinator.push(TestRoute.detail(id: 1), type: .fullScreenCover)
        
        let childCoordinator = coordinator.createChildCoordinator(
            identifier: "child-test",
            initialRoute: ChildTestRoute.childHome
        ) { _, _ in }
        
        // When: Resetting the coordinator
        coordinator.reset()
        
        // Then: All state should be cleared
        XCTAssertEqual(coordinator.path.count, 0)
        XCTAssertNil(coordinator.sheet)
        XCTAssertNil(coordinator.fullscreenCover)
        XCTAssertEqual(coordinator.localStack.count, 1)
        XCTAssertEqual(coordinator.localStack.first, .home)
    }
    
    func test_fullScreenCoverBehavior() {
        // Given: A coordinator
        XCTAssertNil(coordinator.fullscreenCover)
        
        // When: Presenting full screen cover
        coordinator.push(TestRoute.settings, type: .fullScreenCover)
        
        // Then: Full screen cover should be set
        XCTAssertEqual(coordinator.fullscreenCover, TestRoute.settings)
        
        // When: Dismissing programmatically
        coordinator.goBack(.dismissFullScreenCover)
        
        // Then: Full screen cover should be nil
        XCTAssertNil(coordinator.fullscreenCover)
    }
    
    func test_replaceNavigation() {
        // Given: A coordinator with some navigation
        coordinator.push(TestRoute.profile)
        coordinator.push(TestRoute.settings)
        XCTAssertEqual(coordinator.path.count, 2)
        
        // When: Replacing with a new route
        coordinator.push(TestRoute.detail(id: 999), type: .replaceRoot)
        
        // Then: Path should be cleared and initial route should be updated
        XCTAssertEqual(coordinator.path.count, 0)
        XCTAssertEqual(coordinator.initialRoute, TestRoute.detail(id: 999))
        XCTAssertEqual(coordinator.localStack.count, 1)
        XCTAssertEqual(coordinator.localStack.first, TestRoute.detail(id: 999))
    }
}
