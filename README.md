#  NavigationCoordination in SwiftUI

## Preamble

I've never been satisfied with typical solutions you might see for NavigationCoordination in a pure SwiftUI environment.  They always seem designed for the trivial case, like you know, teaching you a technology by learning how to make a data structure for a blog post.  Those barely help beyond the trivial case.

### Inherent deficits in solutions I've seen:

1. Strong typing that forces a flat hierarchy of routes.
- A Coordinator will manage Routes that are often typed to one single enum; thus you have one large hierarchy.
- A Coordinator is designed for one NavigationStack containing routes of the above type.
- You therefore cannot push a child coordinator onto this stack due to type restrictions, despite this being a common use case (you have coordinators for smaller screen flows, which in theory allow re-usability).  Imagine the use case of "drill-down through this folder hierarchy to select a file and once selected, return to the context that triggered this file browsing."  That would all take place on the same navigation stack (or could).

2. Responding to non-programmatic stack changes.
    - Coordinators often don't cover the navigation of when a user taps a back button or uses the interactivePopGesture that is native to NavigationStack (or UINavigationController) and thus provides no callback.  Sometimes you need that callback in order to do something.

3. What about dependency injection? Accommdating a MVVM pattern?

As a result, for some years I have been using SwiftUI to make "screen level" views that would be embedded in `UIHostingController` types and then using UIKit as the backbone of any apps (for its UINavigationController) and Coordinator types that would build the Views and control the navigation controller.  This pattern has worked very well for me but I couldn't find a good analogue in SwiftUI, until now.


## Features

- Allows for multiple flows working on one NavigationStack
- Provides a mechanism for callbacks when a view is dismissed 'non-programmatically' such as a Back button or a InteractivePopGesture (on a navigation stack).

## Usage

See the demo Application Code, starting at NavigationCoordinationSandboxApp.

- You can see we provide an initial route in the appCoordinator that is used to build the initial view.
- We provide this as the environment to a CoordinatorStack (which is a NavigationStack with a Coordinator that manages its NavigationPath).

The app is a MVVM-C architecture.  You can see that the Coordinator is essentially delegating view creation to the Routes you define.  (see `DemoRoutes.swift`)

- In our case, we are faking an app that can view a user profile (and that flow is managed by a Coordinator), have an additional screen for "Settings".  These are all just to show how this app is architected.

- You can see that when a view is built, a ViewModel is created, and supplied to its view.  In the ViewModel, we define "Exits".  The idea is that a View does not want to know anything else about the app's architecture; it exits to accomplish tasks on that view, and when it's finished, it "exits".  (Depending on how it exits, with or without a payload.)

- Because Coordinator types are classes, you can create subclasses that store values throughout your flow.  So one screen can finish with a value, store it, then move to another screen, etc. then at some point finish.

   


## Nomenclature

A "ChildCoordinatorStack" is one where you can use the same NavigationStack to push views associated with completely different Routable types.

A "Child Coordinator" is less clearly defined, but is one that handles navigation flows, just like a regular Coordinator. 


## Suggestions for Future Work / To Do

- Expand this demo to showcase the functionality of sheets and fullcover (this hasn't really been explored or tested yet.)


## Feedback Welcome!

oconnor.freelance@gmail.com or via github.com/horseshoe7

## Acknowledgements

Thank you to Tiago Henriques and his [blog post on the topic ](https://www.tiagohenriques.dev/blog/swiftui-refactor-navigation-layer-using-coordinator-pattern), which got the ball rolling for me, on which this is loosely based.

## LICENSE

MIT.  Or Beerware if you prefer.  Yes, buy me a beer and don't send any lawyers after me.


## TODO

X Ensure that finishCoordinator callback is invoked appropriately when viewDisappeared is called. 
- Ensure you can use exits to modify userData on the Coordinator.
- Discussion: There are still some brittle aspects to this:
    - how 'presentationStyle' gets passed around.  For fullScreenCover you have to know a bit / modify in 2 spots
    - I'd ideally like to hide the addition of .coordinatedView in the makeView methods, but how do I provide the defaultExit to that modifier?
