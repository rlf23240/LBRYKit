# LBRYKit

A simple framework as a swift wrapper of LBRY local daemon build on Combine.

## Functions

### Auto Daemon Management

Auto launch daemon if needed. Including startup, accidentally daemon shutdown, other application (such as LBRY-Desktop) quit, etc.

This can be turn off if you prefer to start daemon manually.

### LBRY Daemon Main Methods

Support main method of lbrynet. See [LBRY-SDK documentation](https://lbry.tech/api/sdk) main section for more information.

Method other then main section can be called, you just need to encode your parameters.

## Build

1. Clone this project.
2. Download [lbry-sdk release](https://github.com/lbryio/lbry-sdk/releases) and put lbrynet into Resources folder. This will be executable for auto daemon management. SDK version at least v0.87.0 is recommanded.
3. Build framework.

## Usage

`LBRYDaemon` is a singleton to manage LBRY daemon. Subscribe `daemonConnectionState` to perform your code.

Here is an example to open a stream.

```
// Wait until daemon avaliable.
LBRYDaemon.shared.$daemonConnectionState.sink() { state in
    if state == .Connected {
        // Send get request to daemon to start a stream.
        subscriber = LBRYDaemon.shared.get(uri: uri, saveFile: false)
            .sink() { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    // Error handling.
                }
            } receiveValue: { result in
                if let streamingURL = result["streaming_url"] as? String {
                    // Start streaming your video by using this URL!
                }
            }
    }
}
```

For method not implemented, you may call it as following:

```
LBRYDaemon.shared.request(method: "claim_list", params: [:])
    .sink() { completion in
        switch completion {
        case .finished:
            break
        case .failure(let error):
            // Error handling.
        }
    } receiveValue: { result in
        // Handle your data here.
    }
}
```

## TODO

* Encapsulate request result with will-organized data structure, instead of dictionary.
* Implement other methods of lbrynet.

## Side Note

If you plain to build a native application with local daemon streaming server (default is localhost:5280), like this framework trying to achieve, you may notice that in current version, Safari (or more spicfic, WebKit and AVFoundation) will reject video due to the range header format. As workaround, cross platform solution, such as VLCKit, can be one of your options.