#  Functional Specs - aka "Make Claude do it"

A listing of behaviours that describe how this needs to work and the tests that need to be generated


1. You can push a route of the same type onto the initialRoute of a Coordinator

2. after pushing a route, you can go back to the initial route 
    - defaultExit should be called in reference to that pushed route when userInitiated == true
    
3. You can replace the current initial view with another route
    - it will empty the local stack.
    - sheets / full cover should ideally be preserved
    - defaultExit on the initial (not new) one should not be called. (because defaultExits are callbacks for userInitiated changes.)
    
4. You can present a sheet from the root coordinator.  
    - you do so by pushing a 'proxy route' of the parent's Routable type
    - where you create the view to be presented in makeView
    - if you push a child coordinator, the branchedBy should be set to the 'proxy route'
    - navigationPath should remain unaffected.

5. root coordinator dismisses a sheet
    - no defaultExit called because userInitiated == false
    
5a. User dismisses a sheet via userInteraction
    - defaultExit called because userInitiated == true

6. root coordinator dismisses a child coordinator presented as a sheet
    - no defaultExit called because userInitiated == false
    
6a. user dismisses a child coordinator presented as a sheet
    - defaultExit called because userInitiated == true

7. A child coordinator presented as a sheet can dismiss itself
    - no defaultExit called because userInitiated == false

8. A child coordinator presented as a sheet can be dismissed via user interaction
    - the parent should then detect the change and fire onFinish and cleanup tasks
    - defaultExits can be invoked BEFORE the Child's onFinish.
        - question: what about defaultExit notifying the coordinator, who in turn will try to finish?
        
    
9, 10, 11.   Same as 5., 6., 7. but for fullScreenCover


12. Pushing a child coordinator onto a common stack.
    - Proxy route is added to navigation path
    - child initial is not, but child initial is added to child's localStack.
    - Child's branchedBy route should be in SharedNavigationPath's routes if the child has been pushed.
    
13. NavigationBackType's popStack(last:) will only pop as far back as its initialRoute.

14. NavigationBackType's popStack(to:) will only be able to pop to a valid route in the child's localStack.

15. popStack to child's initialRoute will take you there.

16. the user navigates backwards past the child coordinator's initial route.
    - defaultExit on child's initial route is called
    - parent detects change and invokes onFinish
    
17. You can finish a child coordinator presented as a sheet programmatically.
    - the parent will take care of dismissing the sheet and invoking the onFinish
    - no defaultExits will be called, as userInitiated == false
    
18. You cannot create a child coordinator whose presentation type is replaceRoot.


Other Tests

30. present sheet with Child Coordinator Flow that then pushes then finishes programmatically
    - no defaultExits should be called.

31. present sheet with child coordinator flow that gets dismissed by user
    - defaultExit should be called on currently presented view in child
    - onFinish called by that.  The parent should pick up on this change.
    
    
     
     

