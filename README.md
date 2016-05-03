# HTTPRequests
__NSURLRequest extensions in Swift__

__Description__

Four different NSURLRequest extensions in Swift:

1. sum type
2. deferred result
3. deferred result and DRError
4. success and error closures

__Features__

- cURL description
- fetch data
- fetch JSON
- fetch typed JSON
- HTTP status, headers, data and NSError

__Motivation__

Demonstrates how to handle errors in an asychronous Swift API.

Initially written as the companion code for my [AppBuilders 2016](https://www.appbuilders.ch/) talk on [error handling](http://seriot.ch/resources/talks_papers/20160426_error_handling.pdf).

__Example__

```swift
    let url = NSURL(string:"http://seriot.ch/objects.json")!
    let request = NSURLRequest(URL: url)
```

1 - sum type

```swift
    request.st_fetchTypedJSON([[String:AnyObject]].self) {
        switch($0) {
        case let .Success(r, json):
            print(r.status, json)
        case let .Failure(r, nsError):
            print(r.status, nsError.localizedDescription)
        }
    }
```

2 - deferred result

```swift
    request.dr_fetchTypedJSON([[String:AnyObject]].self) {
        do {
            let (r, json) = try $0()
            print(r.status, json)
        } catch let e as NSError {
            print(e)
        }
    }
```

3 - deferred result and DRError

```swift
    request.dr2_fetchTypedJSON([[String:AnyObject]].self) {
        do {
            let (r, json) = try $0()
            print(r.status, json)
        } catch let DRError.Error(r, nsError) where r.status == 400 {
            print(r.status, nsError)
        } catch let DRError.Error(r, nsError) {
            print(r.status, nsError)
        } catch {
            assertionFailure()
        }
    }
```

4 - success and error closures

```swift
    request.se_fetchTypedJSON(
        successHandler:{ (r, json:[[String:AnyObject]]) in
            print(json)
        }, errorHandler: { (r, nsError) in
            print(nsError)
        }
    )
```
