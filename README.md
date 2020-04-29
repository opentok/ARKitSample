# ARKit Sample

<img src="https://assets.tokbox.com/img/vonage/Vonage_VideoAPI_black.svg" height="48px" alt="Tokbox is now known as Vonage" />

![OpenTok Labs](https://d26dzxoao6i3hh.cloudfront.net/items/0U1R0a0e2g1E361H0x3c/Image%202017-11-22%20at%2012.16.38%20PM.png?v=2507a2df)
In this repo you will find a sample application combining OpenTok and ARKit.

The sample uses SceneKit to model and render the virtual world. The OpenTok video stream will be renderer in a SceneKit node.

If you want to know more about the sample, please read [the blog post](https://tokbox.com/blog/build-live-video-app-arkit/) which accompanies this sample

## Running the sample

- Install OpenTok sdk by using CocoaPods

`$ pod install`

- Gather OpenTok session credencial from your [account portal](https://tokbox.com/account) and fill the that in the `ViewController.swift` file

```swift
let kApiKey = ""
let kToken = ""
let kSessionId = ""
```

- Setup your provisioning profile for Debug at the project page in Xcode

- Run in a real device. Since the sample is using metal, **iOS Simulator is not supported**

## Development and Contributing

Interested in contributing? We :heart: pull requests! See the
[Contribution](CONTRIBUTING.md) guidelines.

## Getting Help

We love to hear from you so if you have questions, comments or find a bug in the project, let us know! You can either:

- Open an issue on this repository
- See <https://support.tokbox.com/> for support options
- Tweet at us! We're [@VonageDev](https://twitter.com/VonageDev) on Twitter
- Or [join the Vonage Developer Community Slack](https://developer.nexmo.com/community/slack)
