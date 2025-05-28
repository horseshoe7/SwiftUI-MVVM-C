#  Functional Specs

1. Consider the following files (Routable.swift, CoordinatorStack.swift).  These are pretty well specified and functioning, so they would be the last resort to modify in order to change the code to meet the functional specs.

2. The Coordinator is a way to manage the flow of screens.  A View (or View Model) can be created via a Coordinator (or rather the coordinator delegates via the makeView function to its Routable type)

3. If I push a Route, it should add to the SharedNavigationPath

4. If I finish a coordinator, it should be removed from the parent.

5.  
