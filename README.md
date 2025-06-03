#  NavigationCoordination in SwiftUI

## Preamble

I've never been satisfied with typical solutions you might see for NavigationCoordination in a pure SwiftUI environment.  They always seem designed for the trivial case, like you know, teaching you a technology by learning how to make a data structure for a blog post.  Those barely help beyond the trivial case.

### Inherent deficits in solutions I've seen:

1. Strong typing that forces a flat hierarchy of routes.
- A Coordinator will manage Routes that are often typed to one single enum; thus you have one large hierarchy.
- A Coordinator is designed for one NavigationStack containing routes of the above type.
    - This often means you have to create a large set of routes for whatever you want to push onto a common NavigationStack, which breaks the principle of separation of concerns.
- You therefore cannot push a child coordinator onto this stack due to type restrictions, despite this being a common use case (you have coordinators for smaller screen flows, which in theory allow re-usability).  Imagine the use case of "drill-down through this folder hierarchy to select a file and once selected, return to the context that triggered this file browsing."  That would all take place on the same navigation stack (or could).

2. Responding to non-programmatic stack changes.
    - Coordinators often don't cover the navigation of when a user taps a back button or uses the interactivePopGesture that is native to NavigationStack  and thus provides no callback.  Sometimes you need that callback in order to do something.

3. What about dependency injection? Accommdating a MVVM pattern?

As a result, for some years I have been using SwiftUI to make "screen level" views that would be embedded in `UIHostingController` types and then using UIKit as the backbone of any apps (for its UINavigationController) and Coordinator types that would build the Views and control the navigation controller.  This pattern has worked very well for me but I couldn't find a good analogue in SwiftUI, until now.


## Features

- Allows for multiple flows working on one NavigationStack
- Provides a mechanism for callbacks when a view is dismissed 'non-programmatically' such as a Back button or a InteractivePopGesture (on a navigation stack). (known as a 'defaultExit')
- Allows for deeper customization of Coordinator types, but also makes it easy to pass data from Screen to Coordinator.

## Concepts

This project represents a small learning curve to understand how data is structured.

### How to pass data around


The idea is that a View is created and managed by a coordinator.  A View should only talk to its coordinator, and a coordinator manages the state of what's currently visible / presented.  A Coordinator creates and configures a view, and you can use / subclass Coordinators to include mechanisms such as dependency injection.   

If a view is finished (in our examples, we use the idea of "Exits" in a View Model), it notifies its coordinator.  The coordinator is responsible for knowing what to do after that (for example, as a child, pushing a new view, or the coordinator itself can 'finish').

a 'defaultExit' is a callback that you can provide for situations where you otherwise cannot control navigation programmatically, such as when a user taps a back button, swipes to go back, or swipes a sheet down to dismiss it.  In this case, you have the opportunity to provide a callback in this scenario.

There is a 'onDefaultExit' view modifier for when you set up your view in the coordinator.

A Coordinator manages Routables of the same type.  A Child Coordinator can be created to manage routes of a different type, and compose how they relate to their parent. 

Whenever you create a Child coordinator, it needs a reference to a "proxy route" defined in the parent's Routables.  So that when you push the proxy route, you can use that to build a child coordinator.  This is what the idea "branchedFrom" means.  A 'branchedFrom' is a route in the parent and is basically equivalent to the 'initialRoute' in the child, just with different "Route namespaces".  If you pop the branchedFrom from the parent, it will mean the the child coordinator is finished.



## Usage

I recommend downloading the code, and running the app to see generally the functionality that has been made possible with these Coordinator patterns.

Then see the demo Application Code, starting at NavigationCoordinationSandboxApp.

- You can see we provide an initial route in the appCoordinator that is used to build the initial view.

- We provide this as the environment to a CoordinatorStack (which is a NavigationStack with a Coordinator that manages its NavigationPath).

The app is a MVVM-C architecture.  You can see that the Coordinator is essentially delegating view creation to the Routes you define.  (see `DemoRoutes.swift`)

- In our case, we are faking an app that can view a user profile (and that flow is managed by a Coordinator), have an additional screen for "Settings" and a modal screen flow for authentication.  These are all just to show how this app is architected.

- You can see that when a view is built, a ViewModel is created, and supplied to its view.  In the ViewModel, we define "Exits".  The idea is that a View does not want to know anything else about the app's architecture; it exits to accomplish tasks on that view, and when it's finished, it "exits".  (Depending on how it exits, with or without a payload.)

- You can see in the makeView methods that we can specify what the 'defaultExit' will be, in the event the user initiates 'going back', such as back buttons or swipes.  You may need to pass state or do some cleanup in these scenarios.

- Because Coordinator types are classes, you can create subclasses that store values throughout your flow.  So one screen can finish with a value, store it, then move to another screen, etc. then at some point finish.


### Passing Data between screen flows

- See `DemoRoutes.swift` which is essentially all the app's routes and their coordinated flows to see how to use Coordinators

- In the AuthRoutes.makeView implementation, you can see how the result of one screen can set data on the coordinator, then be retrieved on another screen.  This way we maintain the idea that screens only care about themselves, and notify the coordinator when they are done.


## Nomenclature

A "ChildCoordinatorStack" is one where you can use the same NavigationStack to push views associated with completely different Routable types.

A "Child Coordinator" is less clearly defined, but is one that handles navigation flows, just like a regular Coordinator. 


## Feedback Welcome!

oconnor.freelance@gmail.com or via github.com/horseshoe7

See the TODO Items below if you want to get involved in the discussion, or just let me know what you think.

It is perhaps a bit to unpack at the beginning, but this is the first solution to my Coordinator requirements that I've been able to adequately solve with SwiftUI.  Up until now, I've been building UIKit apps that use UIHostingControllers for screens built with SwiftUI.



## Acknowledgements

Thank you to Tiago Henriques and his [blog post on the topic ](https://www.tiagohenriques.dev/blog/swiftui-refactor-navigation-layer-using-coordinator-pattern), which got the ball rolling for me, on which this is loosely based.

## LICENSE

MIT.  Or Beerware if you prefer.  Yes, buy me a beer and don't send any lawyers after me.

