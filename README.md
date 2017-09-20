# SkywiseTilesDemo-iOS
Sample app to demonstrate usage of Skywise tiled data sets on iOS and a couple of approaches to animating tiled data.

Objective-C and Swift view controllers show how to integrate Skywise tile data into your application.


### Prerequisites

- WDT [Skywise](https://skywise.io) Tiles Credentials are **required**.

### Setup

1) Open the file: [AppDelegate.swift](SkywiseTilesDemo/AppDelegate.swift)

2) Modify the SkywiseAuthentication object in `didFinishLaunchingWithOptions` to include your API keys:

```swift
SwarmManager.sharedManager.authentication = SkywiseAuthentication(
	app_id: "your_app_id_from_skywise",
	app_key: "your_app_key_from_skywise"
)
```

3) Without these credentials, you will not be able to access data.

4) To use the code in your application, simply copy the [Swarm](Swarm/) folder and include the source in your Xcode project, and configure your authentication as above.
